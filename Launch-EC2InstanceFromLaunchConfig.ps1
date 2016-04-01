
# enable invocation by script or function call
param
(
    [string]$launchConfigName
);

function Launch-EC2InstanceFromLaunchConfig(
    [Parameter(Mandatory=$true)][string]$launchConfigName,
    [string]$subnetId,
    [string]$overrideInstanceType
    )
{
  $ErrorActionPreference = "Stop"

  $launchConfig = Get-ASLaunchConfiguration -LaunchConfigurationName $launchConfigName

  if ($overrideInstanceType) {
    $instanceType = $overrideInstanceType
  } else {
    $instanceType = $launchConfig.InstanceType
  }

  $reservation = New-EC2Instance `
    -ImageId $launchConfig.ImageId `
    -MinCount 1 -MaxCount 1 `
    -InstanceType $instanceType `
    -SecurityGroupId $launchConfig.SecurityGroups `
    -SubnetId $subnetId `
    -UserData $launchConfig.UserData `
    -InstanceProfile_Name $launchConfig.IamInstanceProfile `
    -KeyName $launchConfig.KeyName

  $instanceId = $reservation.RunningInstance[0].InstanceId
  echo $instanceId
}

function Launch-EC2InstanceFromASGroupTemplate([Parameter(Mandatory=$true)][string]$asgroupName) {
  $ErrorActionPreference = "Stop"

  echo "Querying $asgroupName"
  $asGroup = Get-ASAutoScalingGroup -AutoScalingGroupName $asgroupName
  if (!($asGroup)) {
    write-error "Autoscaling Group not found by name: $asgroupName"
    return
  }

  echo "Launch configuration $($asGroup.LaunchConfigurationName)"
  $instanceId = Launch-EC2InstanceFromLaunchConfig `
    -launchConfigName $asGroup.LaunchConfigurationName `
    -subnetId ($asGroup.VPCZoneIdentifier -split ',')[0]

  if (!($instanceId)) {
    write-error "Instance was not launched"
    return
  }

  # apply any PropagateAtLaunch tags to the instance just as the autoscaling group would have
  $propagateTags = @()
  $asGroup.Tags | % {
    $keyValue = $_.Value
    # append "Test Launch" to the name so it isn't confused with real members of the ASgroup
    if ($_.Key -eq "Name") {
      $keyValue += " (Test Launch)"
      $instanceName = $keyValue
    }

    $tag = @( @{key=$_.Key;value="$keyValue"} )
    $propagateTags += $tag
  }

  $instanceId | New-EC2Tag -Tags $propagateTags

  echo "Tagged $instanceId as '$instanceName' and applied $($propagateTags.Length - 1) other tags."
}

# if the script was called with arguments, invoke the function
# if ($launchConfigName) {
#   Launch-EC2InstanceFromLaunchConfiguration -launchConfigName $launchConfigName
# }
