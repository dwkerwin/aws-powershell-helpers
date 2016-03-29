# returns instances only for any matching the name (case sensitive)
function List-EC2InstancesByName($name)
{
    $instanceList = aws ec2 describe-instances --filters "Name=tag:Name,Values=*$name*" | ConvertFrom-Json

    $runningInstances = $instanceList.Reservations.Instances | `
        # where { $_.State.Name -eq "running" } | `
        select InstanceId, InstanceType, VpcId, State, LaunchTime, Tags | `
        sort VpcId, LaunchTime -desc

    if ($runningInstances.Count -eq 0) {
        echo "No matching instances.  Remember tag name compare is case sensitive :("
    } else {
        $runningInstances | ft -auto
    }
}
set-alias liste List-EC2InstancesByName
