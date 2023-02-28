<#

        Author: Rachel Catches-Ford - IDG
        Description:
                Removes profiles that are a certain age or older. 
                Based on Event Log instance ID: 4624 for each profile.

#>

## Paramaters ##
Param(
    [int]$Days = 30,
    [array]$Exclude = @(),
    [string]$Remove = $false
)

Start-Transcript -Path "C:\Windows\Logs\Software\Remove-OldProfiles_$(Get-Date -Format yyyyMMdd).log" -Append

## Create Arrays and Variables
$UserProfilesArr = @()
$Exclude += @("default", "Public", $env:USERNAME, "SQL", "siteITFO") ## Standard accounts to ignore

# Get user names from CIM Object but remove system users
$users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object{$_.LocalPath -match 'C:\\Users'}

# Check the Event Logs for successful Logins AFTER the days specified.
$userLogonEvent = Get-EventLog -LogName 'Security' -InstanceId '4624' -After $((Get-Date).AddDays(-$Days))

##Get the List of User folders
$users | ForEach-Object {
    $userName = $_.LocalPath.Replace('C:\Users\','')
    if($userName -match ($Exclude -join '|')){ ## Check if User  is in Exclusion list
        Write-Host "[$userName] was ignored because it is excluded."
    } elseif(($UserLogonEvent.Message -match "$userName") -ne $null) { ## Check to see if the user has logged in more recently than the time specified
            Write-Host "[$userName] was not old enough."
    } else{ ## If the user has not logged in successfully recently then remove their account
            Write-Warning "[$userName] is older than [$Days] days and will be removed."
            $UserProfilesArr += $userName # Add to array for removal
            $UserProfilesArr += $UserProfilesArr | Sort-Object -Verbose
    } ## End of If/Else Statement
        
    
} ## End of Get-ChildItem

if($Remove -ne $false){
    Write-Host "[Remove] switch detected. Removing the specified Profiles."
        ## !! Remove the User Profiles !!
        Get-CimInstance -Class Win32_Userprofile | Where-Object { 
                $UserProfilesArr -match ($_.LocalPath -replace ".*\\" -replace ".*\\") ## -replace ".*\\" is a regex that will remove all characters up to and including the first "\". Doing it twice results in removing "C:\" and then "Users\" from the comparison.
        } | ForEach-Object {
                Write-Host("Deleting [$_]")
                Remove-CimInstance -InputObject $_ -Verbose
        }

}else{
    Write-Host "[Remove] switch was not detected. Nothing was removed."
}


Stop-Transcript

Exit 0