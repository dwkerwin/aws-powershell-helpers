<#
.SYNOPSIS
Ever set termination protection on an auto scaling group and then forget about it and have it
left that way for days?  Nope, me neither.  But someone else might find this useful as a reminder
of which ASG's currently have termiantion protection set.  Consider having this run in your
powershell startup profile.
.PARAMETER silentMode
Optionally, specify if you want this to suppress output in the case where everything is good and
there are no ASG's which have termination protection set.
.EXAMPLE
List-ASGsWithTerminationProtection
List-ASGsWithTerminationProtection -silentMode
#>

function List-ASGsWithTerminationProtection([switch]$silentMode) {
  $asgs = Get-ASAutoScalingGroup
  $asgsWithTermProtection = $asgs | ? {$_.SuspendedProcesses.Length -gt 0}
  $asgsWithTermProtection | select AutoScalingGroupName, SuspendedProcesses

  $msg = "$($asgsWithTermProtection.count) of $($asgs.count) ASG's have termination protection enabled"
  if ($asgsWithTermProtection.count -gt 0) {
    write-host $msg -fore red
  } else {
    if (!($silentMode.IsPresent)) {
      $msg
    }
  }
  
}
