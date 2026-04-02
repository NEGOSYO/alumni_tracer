param(
    [Parameter(Mandatory = $true)]
    [string]$Email,

    [securestring]$Password,

    [string]$PasswordText = "",

    [string]$BaseUrl = "http://localhost/alumni_php",

    [string[]]$Programs = @("BSIT", "BSSW"),

    [string]$MysqlPath = "C:\xampp\mysql\bin\mysql.exe",

    [string]$Database = "alumni_tracer",

    [string]$DbUser = "root",

    [securestring]$DbPassword,

    [string]$DbPasswordText = ""
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Invoke-Api {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [string]$Method = "GET",

        [hashtable]$Headers = @{},

        [object]$Body = $null
    )

    $requestArgs = @{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ContentType = "application/json"
    }

    if ($null -ne $Body) {
        $requestArgs.Body = ($Body | ConvertTo-Json -Compress)
    }

    Invoke-RestMethod @requestArgs
}

function Invoke-MysqlScalar {
    param([string]$Sql)

    if (-not (Test-Path $MysqlPath)) {
        throw "MySQL client not found at '$MysqlPath'."
    }

    $mysqlArgs = @(
        "--batch",
        "--skip-column-names",
        "-u", $DbUser
    )

    if ($script:DbPasswordPlain -ne "") {
        $mysqlArgs += "-p$script:DbPasswordPlain"
    }

    $mysqlArgs += @(
        "-D", $Database,
        "-e", $Sql
    )

    $result = & $MysqlPath @mysqlArgs
    if ($LASTEXITCODE -ne 0) {
        throw "MySQL query failed: $Sql"
    }

    return (($result | Out-String).Trim())
}

function Get-DbStats {
    param([string]$Program = "")

    $safeProgram = $Program.Replace("'", "''")
    $where = "WHERE COALESCE(NULLIF(submission_status, ''), 'submitted') = 'submitted'"
    if ($safeProgram -ne "") {
        $where += " AND program = '$safeProgram'"
    }

    $submitted = [int](Invoke-MysqlScalar "SELECT COUNT(*) FROM tracer_responses $where;")
    $employed = [int](Invoke-MysqlScalar @"
SELECT COUNT(*) FROM tracer_responses
$where AND employment_status IN ('Employed', 'Self-Employed', 'Employer');
"@)
    $signed = [int](Invoke-MysqlScalar @"
SELECT COUNT(*) FROM signed_tracer_submissions
"@ + ($(if ($safeProgram -ne "") { "WHERE program = '$safeProgram';" } else { ";" })))

    $employmentRate = 0
    if ($submitted -gt 0) {
        $employmentRate = [math]::Round(($employed / $submitted) * 100)
    }

    return @{
        submitted       = $submitted
        employed        = $employed
        signed          = $signed
        employment_rate = $employmentRate
    }
}

function ConvertFrom-SecureStringToPlainText {
    param([securestring]$SecureString)

    if ($null -eq $SecureString) {
        return ""
    }

    $credential = New-Object System.Management.Automation.PSCredential ("user", $SecureString)
    return $credential.GetNetworkCredential().Password
}

function Resolve-PlainTextSecret {
    param(
        [securestring]$SecureValue,
        [string]$PlainTextValue
    )

    if (-not [string]::IsNullOrWhiteSpace($PlainTextValue)) {
        return $PlainTextValue
    }

    return (ConvertFrom-SecureStringToPlainText -SecureString $SecureValue)
}

function Get-ChartHealth {
    param(
        [object]$Value,
        [int]$SubmissionCount
    )

    if ($SubmissionCount -le 0) {
        return "no-submissions"
    }

    if ($null -eq $Value) {
        return "missing"
    }

    if ($Value -is [string]) {
        if ($Value.Trim() -eq "" -or $Value -eq "No data") {
            return "empty"
        }
        return "ok"
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @($Value)
        if ($items.Count -eq 0) {
            return "empty"
        }

        $numericValues = @()
        foreach ($item in $items) {
            if ($item -is [int] -or $item -is [double] -or $item -is [decimal]) {
                $numericValues += [double]$item
                continue
            }

            if ($item -is [pscustomobject] -or $item -is [hashtable]) {
                foreach ($key in @("value", "count", "percent", "rate")) {
                    if ($null -ne $item.$key) {
                        $numericValues += [double]$item.$key
                    }
                }
            }
        }

        if ($numericValues.Count -gt 0 -and (($numericValues | Measure-Object -Sum).Sum -eq 0)) {
            return "all-zero"
        }

        return "ok"
    }

    return "ok"
}

function Compare-Value {
    param(
        [string]$Label,
        [object]$Actual,
        [object]$Expected
    )

    if ("$Actual" -eq "$Expected") {
        Write-Host ("[OK] {0}: {1}" -f $Label, $Actual) -ForegroundColor Green
        return $true
    }

    Write-Host ("[WARN] {0}: actual={1}, expected={2}" -f $Label, $Actual, $Expected) -ForegroundColor Yellow
    return $false
}

function Coalesce {
    param(
        [object]$Value,
        [object]$Fallback
    )

    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        return $Fallback
    }

    return $Value
}

Write-Section "Login"
$plainPassword = Resolve-PlainTextSecret -SecureValue $Password -PlainTextValue $PasswordText
if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    throw "Provide either -PasswordText or -Password."
}

$script:DbPasswordPlain = Resolve-PlainTextSecret -SecureValue $DbPassword -PlainTextValue $DbPasswordText

$login = Invoke-Api -Uri "$BaseUrl/login.php" -Method "POST" -Body @{
    email    = $Email
    password = $plainPassword
}

if ($login.status -ne "success" -or [string]::IsNullOrWhiteSpace($login.access_token)) {
    throw "Login failed. Response: $($login | ConvertTo-Json -Compress)"
}

$headers = @{ Authorization = "Bearer $($login.access_token)" }
Write-Host "[OK] JWT issued successfully." -ForegroundColor Green

Write-Section "Admin Tracer Summary"
$dbOverall = Get-DbStats
$adminTracer = Invoke-Api -Uri "$BaseUrl/get_tracer_submissions.php" -Headers $headers

Compare-Value "DB submitted rows vs tracer summary total_alumni" $adminTracer.summary.total_alumni $dbOverall.submitted | Out-Null
Compare-Value "DB submitted rows vs tracer submissions count" $adminTracer.summary.submissions $dbOverall.submitted | Out-Null
Compare-Value "Tracer alumni list size vs DB submitted rows" @($adminTracer.alumni).Count $dbOverall.submitted | Out-Null
Compare-Value "Signed records list size vs DB signed submissions" @($adminTracer.signed_records).Count $dbOverall.signed | Out-Null

Write-Section "Accreditation Report Health"
$adminReport = Invoke-Api -Uri "$BaseUrl/get_reports.php" -Headers $headers
$reportTotal = [int](Coalesce $adminReport.report.kpis.total_responses 0)
Compare-Value "Report KPI total_responses vs report meta included_rows" $reportTotal $adminReport.meta.included_rows | Out-Null

foreach ($chartName in @("employment_bars", "first_job_bars", "relevance_bars", "salary_bars", "skill_bars")) {
    $health = Get-ChartHealth -Value $adminReport.report.charts.$chartName -SubmissionCount $reportTotal
    if ($health -eq "ok" -or $health -eq "no-submissions") {
        Write-Host "[OK] $chartName health: $health" -ForegroundColor Green
    } else {
        Write-Host "[WARN] $chartName health: $health" -ForegroundColor Yellow
    }
}

Write-Section "Dean Program Checks"
foreach ($program in $Programs) {
    Write-Host ""
    Write-Host "-- $program --" -ForegroundColor Magenta

    $dbProgram = Get-DbStats -Program $program
    $programTracer = Invoke-Api -Uri "$BaseUrl/get_tracer_submissions.php?program=$program" -Headers $headers
    $dean = Invoke-Api -Uri "$BaseUrl/dean_dashboard.php?program=$program" -Headers $headers
    $report = Invoke-Api -Uri "$BaseUrl/get_reports.php?program=$program" -Headers $headers

    Compare-Value "$program tracer summary total_alumni vs DB submitted rows" $programTracer.summary.total_alumni $dbProgram.submitted | Out-Null
    Compare-Value "$program dean summary submissions vs DB submitted rows" $dean.summary.submissions $dbProgram.submitted | Out-Null
    Compare-Value "$program dean employment rate vs DB employment rate" $dean.summary.employment_rate $dbProgram.employment_rate | Out-Null

    $reportProgramTotal = [int](Coalesce $report.report.kpis.total_responses 0)
    Compare-Value "$program report total_responses vs meta included_rows" $reportProgramTotal $report.meta.included_rows | Out-Null

    $chartChecks = @{
        "batch_data"      = $dean.batch_data
        "industries"      = $dean.industries
        "top_employers"   = $dean.top_employers
        "job_relevance"   = @($dean.job_relevance.related, $dean.job_relevance.other)
        "employment_bars" = $report.report.charts.employment_bars
        "first_job_bars"  = $report.report.charts.first_job_bars
        "relevance_bars"  = $report.report.charts.relevance_bars
    }

    foreach ($name in $chartChecks.Keys) {
        $health = Get-ChartHealth -Value $chartChecks[$name] -SubmissionCount $dbProgram.submitted
        if ($health -eq "ok" -or $health -eq "no-submissions") {
            Write-Host "[OK] $program $name health: $health" -ForegroundColor Green
        } else {
            Write-Host "[WARN] $program $name health: $health" -ForegroundColor Yellow
        }
    }
}

Write-Section "Done"
Write-Host "Verification finished. Review any [WARN] lines above." -ForegroundColor Cyan
