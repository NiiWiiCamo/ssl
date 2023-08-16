###
### OpenSSL handler script v1.0
###
### customizable version found at https://github.com/NiiWiiCamo/ssl
###
### get openssl: https://wiki.openssl.org/index.php/Binaries
### e.g.: https://www.firedaemon.com/get-openssl
###

param(

  [Parameter(HelpMessage="Path to openssl config file, will search file system otherwise.")]
  [string[]] $configfile,

  [Parameter(ValueFromPipeline=$True, HelpMessage="Hostnames, separated by commas ',' only")]
  [string[]] $hostnames=@(),

  [Parameter(HelpMessage="Path to textfile with one hostname per line. No delimiters like ';' or ','")]
  [string[]] $hostnamefile,
  
  [Parameter(HelpMessage="Country as two letter code")]
  [string[]] $C="DE",
  
  [Parameter(HelpMessage="State as text")]
  [string[]] $ST="Hamburg",
  
  [Parameter(HelpMessage="Location / City as text")]
  [string[]] $L="Hamburg",
  
  [Parameter(HelpMessage="Organization as text")]
  [string[]] $O="MyOrg",
  
  [Parameter(HelpMessage="Department as text")]
  [string[]] $OU="IT",

  [Parameter(HelpMessage="Contact Email address as text")]
  [string[]] $email="emai@mycompany.domain"

)

# test parameter $hostnamefile and read to array. appends to parameter $hostnames
if ([string]::IsNullOrWhiteSpace($hostnamefile)) {
  Write-Debug "no hostnamefile parameter given"
} else {
  Write-Debug "received hostnamefile: $hostnamefile"
  if (Test-Path -PathType Leaf -Path $hostnamefile) {
    $hostnamesfromfile = Get-Content -Path $hostnamefile
    Write-Debug "read $hostnamesfromfile"
    $hostnames += $hostnamesfromfile
  }
}


# check if any hostnames were given via $hostnamefile or $hostnames, else enter loop to ask
if ($hostnames.count -eq 0) {
  Write-Debug "no hostnames given"

  while ($True) {
    $input = Read-Host "Enter hostname [blank for finished]"
    if ([string]::IsNullOrWhiteSpace($input)) {
      break
    } else {
      $hostnames += $input
    }
  }
  # exit if no hostnames given
  if ($hostnames.count -eq 0) {
    Write-Error "no hostnames given. exiting."
    exit
  }

} else {
  Write-Debug "received hostnames: $hostnames"
}

if ([string]::IsNullOrWhiteSpace($configfile)) {
  Write-Debug "no configfile parameter given"
} else {
  Write-Debug "received configfile: $configfile"
  $openssl_env = $configfile
}


# find openssl.exe
Write-Debug "Looking for OpenSSL executable..."
# try $PATH first
$openssl_exe = $(Get-Command openssl -ErrorAction SilentlyContinue).Source

if ($openssl_exe -ne $null) {
  Write-Debug "Found OpenSSL in `$PATH"
}
elseif ($openssl_exe = Get-ChildItem -Recurse -ErrorAction SilentlyContinue -Filter '*openssl*.exe') {
  if ($openssl_exe.count -gt 1) {  # if more than one result
    $openssl_exe = $openssl_exe[0].PSPath # use the first one
  }
}
elseif ($openssl_exe = Get-ChildItem -Path "C:\" -Recurse -ErrorAction SilentlyContinue -Filter '*openssl*.exe'){
  if ($openssl_exe.count -gt 1) {  # if more than one result
    $openssl_exe = $openssl_exe[0].PSPath # use the first one
  }
}
else {
  $openssl_exe = Read-Host -Prompt "Could not locate openssl.exe. Please provide path" # ask for path
}

if (Test-Path -PathType Leaf $openssl_exe) {
  $filepath = $($openssl_exe -split '::')[1]
  Write-Debug "Found OpenSSL at provided path $filepath"
}

# print openssl version
$openssl_version = & $openssl_exe version
Write-Host "OpenSSL version: $openssl_version"



# start working with openssl


# locate env / cnf file if none is given
if ([string]::IsNullOrWhiteSpace($openssl_env)) {
  $openssl_env = Get-ChildItem -Recurse -ErrorAction SilentlyContinue -Filter '*.env'
  $openssl_env = $openssl_env + $(Get-ChildItem -Recurse -ErrorAction SilentlyContinue -Filter '*.cnf')
  if ($openssl_env.count -gt 1) { # if more than one result
    Write-Host "Found more than one config file, please specify:"
    $menu = @{}
    for ($i=1; $i -le $openssl_env.count; $i++) {
      $filepath = $($openssl_env[$i-1].PSPath -split '::')[1]
      Write-Host "[$i]: $filepath"
      $menu.Add($i, ($openssl_env[$i-1]))
    }
    [int]$ans = Read-Host -Prompt "Choose config file to use"
    $openssl_env = $menu.Item($ans)
  }
  # get pspath
  $openssl_env = $openssl_env.PSPath
  $openssl_env = $($openssl_env -split '::')[1]
}

Write-Debug "Using config file at $openssl_env"

Write-Debug "`r`n`r`n"
foreach ($h in $hostnames) {
  Write-Host "generating key and csr for $h..."
  $subj = '/CN=' + $h + '/emailAddress=' + $email + `
'/OU=' + $OU + '/O=' + $O + '/L=' + $L + '/ST=' + $ST + '/C=' + $C

  $san = '"subjectAltName = DNS:' + $h + '"'
  $ekeyusage = '"extendedKeyUsage = serverAuth"'
  $basicconstraints = '"basicConstraints = critical, CA:FALSE"'
  $keyusage = '"keyUsage = keyEncipherment, dataEncipherment"'

  Write-Debug "generating key for $h"
  & $openssl_exe genrsa -out "$h.key" 2048

  Write-Debug "generating csr for $h"
  & $openssl_exe req -new -key "$h.key" -out "$h.csr" -config $openssl_env -subj $subj -addext $keyusage -addext $ekeyusage -addext $basicconstraints -addext $san

  # Write-Debug "finished $h"
}

Write-Host "finished. your files are located at $(pwd)"
