function ReplaceEmpty
{
  <#
    Replace an empty string by string given in parameter
    Input:
      - $checkStr: String to check
      - $replacedBy: String to set up if $checkStr is empty
    Output: 
      - $checkStr
  #>
  param(
    [String]$checkStr,
    [String]$replacedBy
  )
  if ($checkStr -match "^\s*$") { $checkStr = $replacedBy }
  return $checkStr
}