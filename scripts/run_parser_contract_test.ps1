param(
    [string]$OutDir = ".tmp\parser-contract-test"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$absoluteOut = Join-Path $projectRoot $OutDir
New-Item -ItemType Directory -Force -Path $absoluteOut | Out-Null

$sources = @(
    "app\src\main\java\com\s1dechain\olcrtcvpn\OlcConfig.java",
    "app\src\main\java\com\s1dechain\olcrtcvpn\OlcUriParser.java",
    "app\src\test\java\com\s1dechain\olcrtcvpn\OlcUriParserContractTest.java"
)

$absoluteSources = $sources | ForEach-Object { Join-Path $projectRoot $_ }

javac -encoding UTF-8 -d $absoluteOut $absoluteSources
java -cp $absoluteOut com.s1dechain.olcrtcvpn.OlcUriParserContractTest
