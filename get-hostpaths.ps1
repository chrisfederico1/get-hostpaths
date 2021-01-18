#Check storage paths on all ESXi hosts FAST!

$views = Get-View -ViewType "HostSystem" -Property Name,Config.StorageDevice -SearchRoot (Get-Datacenter "DatacenterName" | Get-View).MoRef
$result = @()
 
foreach ($view in $views | Sort-Object -Property Name) {
    Write-Host "Checking" $view.Name
 
    $view.Config.StorageDevice.ScsiTopology.Adapter |?{ $_.Adapter -like "*FibreChannelHba*" } | %{
        $hba = $_.Adapter.Split("-")[2]
 
        $active = 0
        $standby = 0
        $dead = 0
 
        $_.Target | %{ 
            $_.Lun | %{
                $id = $_.ScsiLun
 
                $multipathInfo = $view.Config.StorageDevice.MultipathInfo.Lun | ?{ $_.Lun -eq $id }
 
                $a = [ARRAY]($multipathInfo.Path | ?{ $_.PathState -like "active" })
                $s = [ARRAY]($multipathInfo.Path | ?{ $_.PathState -like "standby" })
                $d = [ARRAY]($multipathInfo.Path | ?{ $_.PathState -like "dead" })
 
                $active += $a.Count
                $standby += $s.Count
                $dead += $d.Count
            }
        }
 
        $result += "{0},{1},{2},{3},{4}" -f $view.Name.Split(".")[0], $hba, $active, $dead, $standby
    }
}
 
ConvertFrom-Csv -Header "VMHost", "HBA", "Active", "Dead", "Standby" -InputObject $result | ft -AutoSize

