# Install-IIS.ps1

Install-WindowsFeature -name Web-Server -IncludeManagementTools
$content = @"
<html>
<body>
    <h1>Hola Mundo</h1>
</body>
</html>
"@
$content | Out-File -FilePath "C:\inetpub\wwwroot\index.html"
