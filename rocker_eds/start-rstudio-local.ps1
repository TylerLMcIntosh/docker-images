$Image = "tylerlmcintosh/rocker_eds:4.6-cran20260501"
$HostPort = 8787
$DevDir = "C:\Users\tymc5571\dev"
$ContainerDevDir = "/home/rstudio/dev"
$Password = "123"
$Url = "http://localhost:$HostPort"

$DockerCommand = "docker run --rm -it -p ${HostPort}:8787 -e PASSWORD=$Password -v `"${DevDir}:${ContainerDevDir}`" -w $ContainerDevDir $Image"

Write-Host "Starting container:"
Write-Host $DockerCommand

Start-Process powershell -ArgumentList "-NoExit", "-Command", $DockerCommand

Start-Sleep -Seconds 4

Start-Process $Url