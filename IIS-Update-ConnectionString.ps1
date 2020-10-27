<#
.SYNOPSIS
    Gets all websites on given IIS server and updates their connectionString in web.config to point to new Microsoft SQL server.

.DESCRIPTION
    This script should be used in conjuction with IISDataTierUpdate.ps1 runbook. 


.INPUTS
    Name of new Microsoft SQL server to which IIS server should point.
    For default Microsoft SQL instance, it will be SQL virtual machine Name. For named SQL instance it will be SQL <VMName>\SQLInstanceName

.OUTPUTS
    None.

.NOTE
    The script is to be run only on Azure classic resources. It is not supported for Azure Resource Manager resources.

    Author: sakulkar@microsoft.com
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLServerName
)

try
{
    $sites=Get-Website

    foreach($site in $sites)
    {
        $pspath="IIS:\Sites\"+$site.name
        $FolderPath=Get-WebConfigFile -PSPath $pspath
        $confipath=$FolderPath.DirectoryName+"\web.config"
        $xml = [xml](get-content $confipath -ErrorAction Stop)
        $dbInfo = $xml.SelectNodes("/configuration/connectionStrings/add")
        $ConnectionString=$dbInfo.connectionString
        $connectionName=$dbInfo.name
        $arr=$ConnectionString.split(";")
        $ConnectionStringNew=""

        foreach($str in $arr)
        {
            if($str -like "Data Source*")
            {
                $str="Data Source="+$SQLServerName
            }
            if(!$str.Equals(""))
            {
                $ConnectionStringNew+=$str+";"
            }
        }
        Stop-Service w3svc;

        $pathVariable=$env:windir+"\system32\inetsrv"

        cd $pathVariable

        try
        {
            .\appcmd set config $site.name -section:connectionStrings /"[name='$connectionName'].connectionString:$connectionstringnew"
        }
        catch
        {
            throw("Unable to update Server farm")
        }

        Start-Service w3svc
    }
}	
catch{
    Start-Service w3svc
    $ErrorMessage = $_.Exception.Message
    throw($ErrorMessage)
}