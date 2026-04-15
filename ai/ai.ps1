# ai.ps1

$IncludePatterns = @(
    "*.php", 
    "*.xml"
)

$ManualExcludePatterns = @()

function Get-ScriptDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($MyInvocation.MyCommand.Path) {
        return (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }

    return (Get-Location).Path
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $baseUri = New-Object System.Uri(($BasePath.TrimEnd('\') + '\'))
    $fullUri = New-Object System.Uri($FullPath)
    $relativeUri = $baseUri.MakeRelativeUri($fullUri)
    $relativePath = [System.Uri]::UnescapeDataString($relativeUri.ToString())

    return ($relativePath -replace '\\', '/')
}

function Convert-GitIgnorePatternToRegex {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    $isNegation = $false
    $isDirectoryOnly = $false
    $isAnchored = $false

    if ($Pattern.StartsWith("!")) {
        $isNegation = $true
        $Pattern = $Pattern.Substring(1)
    }

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        return $null
    }

    if ($Pattern.StartsWith("/")) {
        $isAnchored = $true
        $Pattern = $Pattern.Substring(1)
    }

    if ($Pattern.EndsWith("/")) {
        $isDirectoryOnly = $true
        $Pattern = $Pattern.Substring(0, $Pattern.Length - 1)
    }

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        $Pattern = "*"
    }

    $regex = ""
    $i = 0

    while ($i -lt $Pattern.Length) {
        $ch = $Pattern[$i]

        if ($ch -eq '*') {
            if (($i + 1) -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                $nextIsSlash = (($i + 2) -lt $Pattern.Length -and $Pattern[$i + 2] -eq '/')

                if ($nextIsSlash) {
                    $regex += '(?:.*/)?'
                    $i += 3
                    continue
                }
                else {
                    $regex += '.*'
                    $i += 2
                    continue
                }
            }
            else {
                $regex += '[^/]*'
                $i += 1
                continue
            }
        }
        elseif ($ch -eq '?') {
            $regex += '[^/]'
            $i += 1
            continue
        }
        elseif ($ch -eq '/') {
            $regex += '/'
            $i += 1
            continue
        }
        else {
            $regex += [regex]::Escape([string]$ch)
            $i += 1
            continue
        }
    }

    $hasSlash = $Pattern.Contains("/")

    if ($isAnchored) {
        if ($isDirectoryOnly) {
            $fullRegex = '^' + $regex + '(?:/.*)?$'
        }
        else {
            $fullRegex = '^' + $regex + '$'
        }
    }
    else {
        if ($hasSlash) {
            if ($isDirectoryOnly) {
                $fullRegex = '^(?:.*/)?' + $regex + '(?:/.*)?$'
            }
            else {
                $fullRegex = '^(?:.*/)?' + $regex + '$'
            }
        }
        else {
            if ($isDirectoryOnly) {
                $fullRegex = '^(?:.*/)?' + $regex + '(?:/.*)?$'
            }
            else {
                $fullRegex = '^(?:.*/)?' + $regex + '$'
            }
        }
    }

    [PSCustomObject]@{
        Original      = $Pattern
        Regex         = $fullRegex
        Negation      = $isNegation
        DirectoryOnly = $isDirectoryOnly
        Anchored      = $isAnchored
    }
}

function Read-GitIgnoreRules {
    param(
        [Parameter(Mandatory = $true)][string]$GitIgnorePath
    )

    $rules = @()

    if (-not (Test-Path -LiteralPath $GitIgnorePath)) {
        return $rules
    }

    $lines = [System.IO.File]::ReadAllLines($GitIgnorePath)

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()

        if ($line.Length -eq 0) {
            continue
        }

        if ($line.StartsWith("#")) {
            continue
        }

        $rule = Convert-GitIgnorePatternToRegex -Pattern $line
        if ($null -ne $rule) {
            $rules += $rule
        }
    }

    return $rules
}

function Test-GitIgnored {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][bool]$IsDirectory,
        [Parameter(Mandatory = $true)][array]$Rules
    )

    $normalizedPath = $RelativePath -replace '\\', '/'
    $ignored = $false

    foreach ($rule in $Rules) {
        if ($rule.DirectoryOnly -and -not $IsDirectory) {
            continue
        }

        if ($normalizedPath -match $rule.Regex) {
            if ($rule.Negation) {
                $ignored = $false
            }
            else {
                $ignored = $true
            }
        }
    }

    return $ignored
}

function Test-IncludeFile {
    param(
        [Parameter(Mandatory = $true)][string]$FileName
    )

    foreach ($pattern in $IncludePatterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Test-ManualExcludeFile {
    param(
        [Parameter(Mandatory = $true)][string]$FileName
    )

    foreach ($pattern in $ManualExcludePatterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Test-AnyParentDirectoryIgnored {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][array]$Rules
    )

    $pathParts = $RelativePath -split '/'
    if ($pathParts.Length -le 1) {
        return $false
    }

    $current = ""
    for ($i = 0; $i -lt ($pathParts.Length - 1); $i++) {
        if ($current) {
            $current += "/"
        }
        $current += $pathParts[$i]

        if (Test-GitIgnored -RelativePath $current -IsDirectory $true -Rules $Rules) {
            return $true
        }
    }

    return $false
}

function New-XmlTextElement {
    param(
        [Parameter(Mandatory = $true)]$XmlDocument,
        [Parameter(Mandatory = $true)]$ParentNode,
        [Parameter(Mandatory = $true)][string]$ElementName,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $node = $XmlDocument.CreateElement($ElementName)
    $node.InnerText = $Text
    [void]$ParentNode.AppendChild($node)
}

function Create-ProjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$ScanRoot,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )

    $gitIgnorePath = Join-Path $ScanRoot ".gitignore"
    $gitRules = Read-GitIgnoreRules -GitIgnorePath $gitIgnorePath

    $xml = New-Object System.Xml.XmlDocument

    $declaration = $xml.CreateXmlDeclaration("1.0", "utf-8", $null)
    [void]$xml.AppendChild($declaration)

    $projectNode = $xml.CreateElement("project")
    [void]$xml.AppendChild($projectNode)

    New-XmlTextElement -XmlDocument $xml -ParentNode $projectNode -ElementName "generated_at" -Text ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
    New-XmlTextElement -XmlDocument $xml -ParentNode $projectNode -ElementName "scan_root" -Text $ScanRoot

    # Папки
    Get-ChildItem -Path $ScanRoot -Recurse -Directory | Sort-Object FullName | ForEach-Object {
        $dir = $_
        $relativePath = Get-RelativePath -BasePath $ScanRoot -FullPath $dir.FullName

        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            return
        }

        if (Test-GitIgnored -RelativePath $relativePath -IsDirectory $true -Rules $gitRules) {
            return
        }

        if (Test-AnyParentDirectoryIgnored -RelativePath $relativePath -Rules $gitRules) {
            return
        }

        $hasVisibleChildren = $false

        foreach ($child in (Get-ChildItem -LiteralPath $dir.FullName -Force)) {
            $childRelativePath = Get-RelativePath -BasePath $ScanRoot -FullPath $child.FullName

            if (Test-AnyParentDirectoryIgnored -RelativePath $childRelativePath -Rules $gitRules) {
                continue
            }

            if ($child.PSIsContainer) {
                if (-not (Test-GitIgnored -RelativePath $childRelativePath -IsDirectory $true -Rules $gitRules)) {
                    $hasVisibleChildren = $true
                    break
                }
            }
            else {
                if (-not (Test-GitIgnored -RelativePath $childRelativePath -IsDirectory $false -Rules $gitRules) -and -not (Test-ManualExcludeFile -FileName $child.Name)) {
                    $hasVisibleChildren = $true
                    break
                }
            }
        }

        if (-not $hasVisibleChildren) {
            Write-Host ("Empty directory: {0}" -f $relativePath)

            $dirNode = $xml.CreateElement("directory")
            [void]$projectNode.AppendChild($dirNode)

            New-XmlTextElement -XmlDocument $xml -ParentNode $dirNode -ElementName "path" -Text $relativePath
            New-XmlTextElement -XmlDocument $xml -ParentNode $dirNode -ElementName "empty" -Text "true"
        }
    }

    # Файлы
    Get-ChildItem -Path $ScanRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        $file = $_
        $relativePath = Get-RelativePath -BasePath $ScanRoot -FullPath $file.FullName

        if (Test-GitIgnored -RelativePath $relativePath -IsDirectory $false -Rules $gitRules) {
            return
        }

        if (Test-AnyParentDirectoryIgnored -RelativePath $relativePath -Rules $gitRules) {
            return
        }

        if (Test-ManualExcludeFile -FileName $file.Name) {
            return
        }

        if (-not (Test-IncludeFile -FileName $file.Name)) {
            return
        }

        Write-Host ("Processing file: {0}" -f $relativePath)

        try {
            $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        }
        catch {
            $content = ""
        }

        $fileNode = $xml.CreateElement("file")
        [void]$projectNode.AppendChild($fileNode)

        New-XmlTextElement -XmlDocument $xml -ParentNode $fileNode -ElementName "path" -Text $relativePath
        New-XmlTextElement -XmlDocument $xml -ParentNode $fileNode -ElementName "size" -Text ([string]$file.Length)

        $contentNode = $xml.CreateElement("content")
        $cdataNode = $xml.CreateCDataSection($content)
        [void]$contentNode.AppendChild($cdataNode)
        [void]$fileNode.AppendChild($contentNode)
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = "  "
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)

    $writer = [System.Xml.XmlWriter]::Create($OutputFile, $settings)
    try {
        $xml.Save($writer)
    }
    finally {
        $writer.Close()
    }

    Write-Host ("Saved: {0}" -f $OutputFile)
}

$scriptDir = Get-ScriptDirectory
$scanRoot = Split-Path -Parent $scriptDir
$outputFile = Join-Path $scriptDir "ai.xml"

Create-ProjectXml -ScanRoot $scanRoot -OutputFile $outputFile
