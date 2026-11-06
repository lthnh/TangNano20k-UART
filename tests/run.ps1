$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$commonSources = @(
    'src/uart_pkg.sv', 'src/uart_if.sv', 'src/uart_clk.sv',
    'src/uart_rx.sv', 'src/uart_tx.sv', 'src/uart_loop.sv'
)

Push-Location $projectDir
try {
    function Invoke-UartSimulation {
        param(
            [string]$Top,
            [string]$TestSource,
            [string[]]$ParameterOverrides = @(),
            [string]$ExpectedFailure = ''
        )
        $simulationPath = Join-Path ([IO.Path]::GetTempPath()) (
            'tang-uart-' + [guid]::NewGuid().ToString('N') + '.vvp'
        )
        try {
            & iverilog -g2012 -s $Top -o $simulationPath @ParameterOverrides @commonSources $TestSource
            if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $Top" }
            $simulationOutput = & vvp $simulationPath
            $simulationExit = $LASTEXITCODE
            $simulationOutput | Write-Output
            if ($ExpectedFailure) {
                if ($simulationExit -eq 0 -or
                    ($simulationOutput -join "`n") -notmatch [regex]::Escape($ExpectedFailure)) {
                    throw "Expected parameter rejection was not observed: $Top"
                }
                Write-Output 'PASS: invalid divider configuration rejected'
            } elseif ($simulationExit -ne 0) {
                throw "Simulation failed: $Top"
            }
        } finally {
            if (Test-Path -LiteralPath $simulationPath) {
                Remove-Item -LiteralPath $simulationPath
            }
        }
    }

    foreach ($test in @('tb_uart_rx', 'tb_uart_loop', 'tb_uart_review')) {
        Invoke-UartSimulation -Top $test -TestSource "tests/$test.sv"
    }
    foreach ($baud in @(9600, 300, 110)) {
        Invoke-UartSimulation -Top tb_uart_clk_review -TestSource tests/tb_uart_review.sv `
            -ParameterOverrides @('-P', "tb_uart_clk_review.TEST_BAUD=$baud")
    }
    # Power-of-two periods, with both counters exceeding the original widths.
    Invoke-UartSimulation -Top tb_uart_clk_review -TestSource tests/tb_uart_review.sv `
        -ParameterOverrides @('-P', 'tb_uart_clk_review.TEST_FREQ=2097152',
                              '-P', 'tb_uart_clk_review.TEST_BAUD=1')
    # Minimum supported RX clock period (two system cycles).
    Invoke-UartSimulation -Top tb_uart_clk_review -TestSource tests/tb_uart_review.sv `
        -ParameterOverrides @('-P', 'tb_uart_clk_review.TEST_FREQ=32',
                              '-P', 'tb_uart_clk_review.TEST_BAUD=1')
    Invoke-UartSimulation -Top tb_uart_clk_review -TestSource tests/tb_uart_review.sv `
        -ParameterOverrides @('-P', 'tb_uart_clk_review.TEST_FREQ=16',
                              '-P', 'tb_uart_clk_review.TEST_BAUD=1') `
        -ExpectedFailure 'UART clock dividers must each be at least two system cycles'
    Invoke-UartSimulation -Top tb_uart_clk_review -TestSource tests/tb_uart_review.sv `
        -ParameterOverrides @('-P', 'tb_uart_clk_review.TEST_BAUD=0') `
        -ExpectedFailure 'UART clock parameters must be positive'
} finally {
    Pop-Location
}
