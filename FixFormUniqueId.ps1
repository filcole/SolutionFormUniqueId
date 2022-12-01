# TEMPORARY: There's currently a bug(?) in the platform that causes the uniqueid on forms 
# change case, even though same value. Note uniqueid is not always output.  
# This causes dirty diffs for forms that haven't actually changed. We resolve this here 
# by searching for any uppercase GUIDs for the uniqueid attribute and lowercasing them. 

param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the path to the unpacked solution")]
    [Alias("p", "path")]
    [string]$solutionfolder
)

Function CheckSolutionFolder {

    if (!( Test-Path -Path $solutionfolder -PathType Container)) {
        Write-Error "Could not find folder $solutionfolder"
        exit
    }
    
    # Resolve any relative folder provided to script to full pathname
    $solnxml = Resolve-Path $solutionfolder

    $solnxml = Join-Path $solnxml "Other"
    $solnxml = Join-Path $solnxml "Solution.xml"

    if (!( Test-Path -Path $solnxml -PathType Leaf)) {
        Write-Error "Not valid solution folder. $solnxml does not exist"
        exit
    }
}

CheckSolutionFolder

$solutionfolder = Resolve-Path $solutionfolder
Write-Host "Scanning forms for uppercase uniqueid GUIDs in $solutionfolder" 

$entitiesFolder = Join-Path $solutionfolder "Entities"
$reUniqueId = 'uniqueid="\{([A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12})\}"' 

# For all FormXml folders in a solution (i.e. per table/entity) 
$formXmlFolders = Get-ChildItem -Path "$entitiesFolder" -Recurse -Directory -Filter "FormXml" 

$formXmlFolders | ForEach-Object { 
    # Get the list of *.xml files in an entities FormXml folder that contain an upper case unique Id guid 
    $formsToFix = Get-ChildItem -Path $_.PSPath -Recurse -File -Filter "*.xml" | Select-String -Pattern $reUniqueId -CaseSensitive -List  

    # For all the forms with uppercase guids 
    $formsToFix | ForEach-Object { 

        # Read the form content into memory
        $formToFix = $_
        $formXml = Get-Content -path $formToFix.Path -Raw

        # Get a unique list of uniqueid GUIDs, just incase the same guid appears twice (should not happen!)

        $uniqMatches = $formXml | Select-String -Pattern $reUniqueId -CaseSensitive -AllMatches
        $uniqueGuids = $uniqMatches.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object | Get-Unique

        # Get the relative path - just to make the path shown in the log friendlier
        $relativePath = Get-Item $formToFix.Path | Resolve-Path -Relative

        Write-Host "Fixing $($uniqueGuids.Count) guids on $($uniqMatches.Matches.Count) occurrences in form $relativePath"

        # Replace each uppercase guid with a lowercase version
        $uniqueGuids | ForEach-Object {
            $uniqueId = ' uniqueid="{' + $_ + '}"'
            Write-Debug "Processing $uniqueId"
 
            # Convert Guid to lowercase. Note: C# Guid.NewGuid().ToString() returns lowercase
            $normalisedUniqueId = ' uniqueid="{' + $_.ToLower() + '}"'

            $formXml = $formXml -replace $uniqueid, $normalisedUniqueId
        }

        # Save the fixed form
        $formXml | Set-Content -NoNewLine -Path $formToFix.Path
    } 
}