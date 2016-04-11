<#
.SYNOPSIS
Scans all unused EBS volumes and displays the AMI the volume was last attached to, which is
useful to determine if it is safe to delete them. Unattached EBS volumes provide very little
identifying information on how the volume was last used. EBS volumes which have snapshot associated
with them have a default snapshot Description which includes the AMI Id, which may be useful in
determining the instance or autoscaling group it was associated with.

Read only use of Get-EC2Volume, Get-EC2Snapshot, Get-EC2Image
#>
function Audit-UnusedEbsVolumes() {
    $volumes = Get-EC2Volume -Filter @{ Name="status"; Values="available" }

    echo "$($volumes.Length) unused EBS volumes found..."

    $unusedEbsInfo = @()
    $volumes | % {
        $volume = $_
        $snapshot = Get-EC2Snapshot -SnapshotId $volume.SnapshotId

        # parse out the ami id from the description
        # Example default AWS snapshopt description format:
        #   "Created by CreateImage(i-abcd1234) for ami-abcd1234 from vol-abcd1234"
        $foundAmi = $snapshot.Description -match 'ami-\S+'
        if ($foundAmi) {
            $amiId = $matches[0]
            $ami = Get-EC2Image -ImageId $amiId

            $ebsInfo = New-Object –TypeName PSObject –Prop @{
                VolumeId = $volume.VolumeId;
                CreatedOn = get-date($volume.CreateTime) -format "yyyy-MM-dd";
                Status = $volume.Status;
                Attachments = $volume.Attachments.Length;
                Size = $volume.Size;
                SnapshotId = $snapshot.SnapshotId;
                AmiId = $ami.ImageId;
                AmiName = $ami.Name            
            }
            $unusedEbsInfo += $ebsInfo
        } else {
            write-host "Could not parse AMI from snapshot description for volume $($volume.VolumeId)." -fore red
            write-host "Snapshot Description: $($snapshot.Description)" -fore red
        }
    }

    $unusedEbsInfo | `
        sort-object -property CreatedOn -descending | `
        format-table VolumeId, AmiName, CreatedOn, Status, Attachments, *
}    
    
