function CalcCores
{
  <#
    Retrieve for VM with Hybrid Benefit number of:
    - Cores consumed
    - Licenses consumed
    - Cores wasted
    Input:
      - $nbCores: number of cores of the VM
      - $coresByLicense: Number of cores by license
    Output:
      - $calcCores: array of results
  #>
  param(
    [Int16] $nbCores,
    [int16] $coresByLicense
  )

  $calcCores = @{
    coresConsumed = 0
    licensesConsumed = 0
    coresWasted = 0
  }

  $floor = [Math]::Floor($nbCores/$coresByLicense)
  $modulus = $nbCores % $coresByLicense

  if ($floor -eq 0 -or $nbCores -eq $coresByLicense) {
    $calcCores['coresConsumed'] = $coresByLicense
    $calcCores['licensesConsumed'] = 1
    $calcCores['coresWasted'] = $coresByLicense - $nbCores
  }
  else {
    switch ($modulus) {
      { $_ -eq 0 } {
        $calcCores['coresConsumed'] = $coresByLicense * $floor
        $calcCores['licensesConsumed'] = $floor
        $calcCores['coresWasted'] = 0
      }
      { $_ -gt 0 } {
        $calcCores['coresConsumed'] = ($coresByLicense * $floor) + $coresByLicense
        $calcCores['licensesConsumed'] = $floor + 1
        $calcCores['coresWasted'] = ($coresByLicense * ($floor + 1)) - $nbCores
      }
    }
  }
  return $calcCores
}

$resultCores = CalcCores -nbCores 30 -coresByLicense 8
Write-Host "nbCore = 30 et cores par licence = 8"
Write-Host "Cores consumed:" $resultCores['CoresConsumed']
Write-Host "Licenses consumed:" $resultCores['licensesConsumed']
Write-Host "Cores wasted:" $resultCores['coresWasted']