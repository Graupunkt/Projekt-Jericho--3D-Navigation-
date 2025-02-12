# Script to use CIG Coordinate System with Status Update

##################
### Parameters ###
##################

$ErrorActionPreference = 'SilentlyContinue'
$debug = $false
#$debug = $true 
$UseTestdata = $false
#$UseTestdata = $true

#CLEAR ALL VARIABLES FROM RPEVIOUS RUN
if($debug){
    $DefaultVariables = Get-Variable -Scope GLOBAL
    $DefaultVariables += "debug"
    $DefaultVariables += "UseTestdata"
    $DefaultVariables += "ErrorActionPreference"
    $ExcludeList = $DefaultVariables.Name -join ','
    Get-Variable -Exclude $ExcludeList | Clear-Variable 
    Remove-Module *
    if($error){$error.Clear()}
}

#SELECT CURRENT POI / DESTINATION FROM HASBTABLE LINE 22
$DistanceGreen = 1000      # Set Distance in meters when values should turn green (1km)
$DistanceYellow = 100000    # Set Distance in meters when values should turn yellow (100km)
$QMDistanceGreen = 100000    # QM Distance Green
$QMDistanceYellow = 1000000   # QM Distance Yellow

#GLOBAL PARAMETERS
$CustomCoordsProvided = $false  #set to false per default, in case not selected or script is run again 
$StartNavigation = $false
$script:PlanetaryPoi = $false  
$Powershellv5Legacy = $false   
$ClipboardContent = ""          #set empty clipboard content, in case of rerun
$FinalInstructions = @()
$script:ListOfToolsToStart = @()
$PreviousTime = 0
$PreviousXPosition = 1
$PreviousYPosition = 1
$PreviousZPosition = 1
#$CurrentXPosition = 0
#$CurrentYPosition = 0
#$CurrentZPosition = 0
$PreviousZPosition = 0
$ScriptLoopCount = 0
#Set-StrictMode -Version 2.0    #Display all errors while directly running script
Set-Location -Path $PSScriptRoot

#################
### FUNCTIONS ###
#################
 
Function Show-Frontend {
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()
}

Function Set-WindowSize{
    param(
        [int]$newXSize,
        [int]$newYSize
       )
    [Console]::WindowHeight=$newXSize;
    [Console]::WindowWidth=$newYSize;
    #[Console]::WindowHeight=15
    #[Console]::WindowWidth=$newYSize
}

function Move-Window {
    param(
     [int]$newX,
     [int]$newY
    )
    BEGIN {
    $signature = @'

[DllImport("user32.dll")]
public static extern bool MoveWindow(
    IntPtr hWnd,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    bool bRepaint);

[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();

[DllImport("user32.dll")]
public static extern bool GetWindowRect(
    HandleRef hWnd,
    out RECT lpRect);

public struct RECT
{
    public int Left;        // x position of upper-left corner
    public int Top;         // y position of upper-left corner
    public int Right;       // x position of lower-right corner
    public int Bottom;      // y position of lower-right corner
}

'@
    
    Add-Type -MemberDefinition $signature -Name Wutils -Namespace WindowsUtils
    
    }
    PROCESS{
     $phandle = [WindowsUtils.Wutils]::GetForegroundWindow()
    
     $o = New-Object -TypeName System.Object
     $href = New-Object -TypeName System.RunTime.InteropServices.HandleRef -ArgumentList $o, $phandle
    
     $rct = New-Object WindowsUtils.Wutils+RECT
    
     [WindowsUtils.Wutils]::GetWindowRect($href, [ref]$rct)
     
     $width = $rct.Right - $rct.Left
     $height = 700
    <#
     $height = $rct.Bottom = $rct.Top
     
     $rct.Right
     $rct.Left
     $rct.Bottom
     $rct.Top
     
     $width
     $height
    #>
     [WindowsUtils.Wutils]::MoveWindow($phandle, $newX, $newY, $width, $height, $true)
    
    }
}
    
function Keep-ConsoleOnTop {
$signature = @'
[DllImport("user32.dll")]
public static extern bool SetWindowPos(
    IntPtr hWnd,
    IntPtr hWndInsertAfter,
    int X,
    int Y,
    int cx,
    int cy,
    uint uFlags);
'@

$type = Add-Type -MemberDefinition $signature -Name SetWindowPosition -Namespace SetWindowPos -Using System.Text -PassThru
$handle = (Get-Process -id $Global:PID).MainWindowHandle
$alwaysOnTop = New-Object -TypeName System.IntPtr -ArgumentList (-1)
$type::SetWindowPos($handle, $alwaysOnTop, 0, 0, 0, 0, 0x0003)
}

#ENABLE BULTIN POWERSHELL V% SUPPORT
if((Get-Host).Version.Major -eq "5"){
    $Powershellv5Legacy = $true
    $StartNavigation = $true
    Write-Host -ForegroundColor Red "Please install and run with powershell v7"
}

##################
### HASHTABLES ###
##################

$SystemData = @{
    Stanton = "ArcCorp; Crusader; Hurston; Microtech; Daymar; Yela; Cellin; Arial; Aberdeen; Ita; Magda; Clio; Euterpe; Calliope"
}

$QuantummarkerData = @{
    "ArcCorp" = "18587664739.856;-22151916920.3125;0"
    "Crusader" = "-18962176000;-2664959999.99999;0"
    "Hurston" = "12850457093;0;0"
    "Microtech" = "22462016306.0103;37185625645.8346;0"
    "Delamar" = "-10531703478.4293;18241438663.8409;0"
    "ARC-L1" = "16729134637.3846;-19937006924.8913;8076.625"
    "ARC-L2" = "20446718503.3901;-24367450990.706;8076.625"
    "ARC-L3" = "-25043446883.5029;14458841787.628;8076.625"
    "ARC-L4" = "28478354915.6557;5021502482.91174;8076.625"
    "ARC-L5" = "-9890422516.16967;-27173732225.14;8076.625"
    "CRU-L1" = "-17065957375.9999;-2398463999.99999;0"
    #"CRU-L2" = "0;0;0"
    "CRU-L3" = "18962176000;2664960000;0"
    "CRU-L4" = "-7173168639.99999;-17754204160;0"
    "CRU-L5" = "-11789008988.2602;15089246106.7638;0"
    "MIC-L1" = "20215808582.526974;33466996827.765518;767.452183"
    "HUR-L1" = "11565411328;0;0"
    "HUR-L2" = "14135502848;0;0"
    "HUR-L3" = "-12850457600;-1123.42272949218;0"
    "HUR-L4" = "6425228288;11128823808;0"
    "HUR-L5" = "6425227776;11128823808;0"
    #"Stanton-Star" = "136049.868;-1294427.422;2923345.358"
}

$RestStopData = @{
    "ARC-L1-Station" = "-1946.17884540557;-3262.39273452758;3147.92219238728"
    #"ARC-L2-Station" = "0;0;0"
    #"ARC-L3-Station" = "0;0;0"
    #"ARC-L4-Station" = "0;0;0"
    #"ARC-L5-Station" = "0;0;0"
    "CRU-L1-Station" = "-1279569.56942379;-2246919.81820762;-4195881.97904336"
    #"CRU-L2-Station" = "0;0;0"
    #"CRU-L3-Station" = "0;0;0"
    "CRU-L4-Station" = "5141933.59375;-4184999.51171875;3520767.02117919"
    "CRU-L5-Station" = "-1239225.44282674;521321607363224;278730649909377"
    "HUR-L1-Station" = "-1740752.25543975;-3262392.73452758;3147922.19238728"
    "HUR-L2-Station" = "-3496591.01748466;5084344.7265625;2490051.99572071"
    "HUR-L3-Station" = "3834139.85588029;-5216795.82729935;-4718270.97439393"
    "HUR-L4-Station" = "-1088098.63078594;2058350.3563404;1317405.78842163"
    "HUR-L5-Station" = "-6886053.22265625;-5700833.0078125;0448659.982681274"
    "MIC-L1-Station" = "-1946178.84540557;-3262392.73452758;3147922.19238728"
}


$PlanetData = @{
    #Planet     X Axis, Y-Axis, Z-Axsis, RotationSpeed, Rotation Adjustment, OrbitalMarkerRadius
    Daymar = "-18930539.54;-2610158.765;0;2.4800000;29.88665;430018"
}

<#
$HashtableOmRadius = @{
    "Delamar"   = "118890"   #Delamar   Delamar
    "Hurston"   = "1436000"  #Stanton1
    "Arial"     = "501528"   #Stanton1a
    "Aberdeen"  = "402696"   #Stanton1b
    "Magda"     = "494835"   #Stanton1c
    "Ita"       = "472445"   #Stanton1d
    "Crusader"  = "11733500" #Stanton2
    "Ceilin"    = "380520"   #Stanton2a
    "Daymar"    = "430018"   #Stanton2b
    "Yela"      = "455470"   #Stanton2c
    "ArcCorp"   = "1259000"  #Stanton3
    "Lyria"     = "328190"   #Stanton3a
    "Wala"      = "413047"   #Stanton3b
    "MicroTech" = "1439400"  #Stanton4
    "Calliope"  = "352238"   #Stanton4a
    "Clio"      = "489650"   #Stanton4b
    "Euterpe"   = "314050"   #Stanton4c
    }
#>

$PointsOfInterestInSpaceData = @{
    "INS-Jericho" = "20196776944;33456387580;2895692"
    "ProcyonWreckSite" = "20196234302.339825;33456590828.301819;3063800.096146"
}

$PointsOfInterestOnPlanetsData = @{
    #Site                            Planet, X-Coords, Y-Coords, Z-Coords
    "Kudre Ore"                    = "Daymar;146.617154182309;-177.093294377514;-184.862263017951"
    "Eager Flats Aid Shelter"      = "Daymar;200.545063565929;-104.917273995152;190.096594760393"
    "Kudre Ore Mine"               = "Daymar;81.0076702389147;-280.683338081131;43.6486983371916"
    "Shubin Mining Facility SCD-1" = "Daymar;126.025172040445;-149.58146894637;221.25334404046"
    "Wolf Point Aid Shelter"       = "Daymar;-4.41978284451699;279.066633187614;95.7326590587272"
    "Nuen Waste Management"        = "Daymar;-18.9432612462583;293.340930183354;25.4783997551309"
    "ArcCorp Mining Area 141"      = "Daymar;-18.1669995110158;180.36216702036;-232.759931235018"
    "Dunlow Ridge Aid Shelter"     = "Daymar;-51.8496231568687;280.931990013533;75.3312863846513"
    "Javelin (Daymar)"             = "Daymar;102.055;267.619;-70.856"
}

#$PoisOnPlanetData = @{
#    #Site         Moon
#    "Kudre Ore Mine" = "Daymar"
#}







###############################
### PREREQUESTS, ASSEMBLIES ###
###############################
try {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  
    Add-Type -assembly System.Windows.Forms
}
catch {
    Write-Warning -Message 'Unable to load required assemblies'
    return
}

#################
### FUNCTIONS ###
#################
#FUNCTION TO SHOW THE FRONTEND

# RUN SCRIPT WITH ADMIN PERMISSIONS
if(!$debug){
    #If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    #    Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    #    Exit
    #}
}

####################
### FRONTEND, UI ###
####################
# OUTER WINDOW
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(1250,670) 
$Form.Text = "Project Jericho"
$form.StartPosition = 'CenterScreen'

### PROGRESS BAR ###
# https://powershell.anovelidea.org/powershell/windows-forms/
$StatusStrip = New-Object System.Windows.Forms.StatusStrip
$StatusStrip.Name = 'StatusStrip'
#$StatusStrip.AutoSize = $true
$StatusStrip.AutoSize = $false
$StatusStrip.
$StatusStrip.Left = 0
$StatusStrip.Visible = $true
$StatusStrip.Enabled = $true
$StatusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
$StatusStrip.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
#$StatusStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::Table
$StatusStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::HorizontalStackWithOverflow
$StatusStrip.BorderSides = "Left"
$StatusStrip.BorderStyle = "Etched"

$Copyright = [System.Windows.Forms.ToolStripLabel]::new()
$Copyright.Name = 'Copyright'
$Copyright.Text = "© [VORA] Graupunkt, [DSC] Murphy, [IFE] Xabdiben"
$Copyright.Width = 200
$Copyright.Visible = $true

$Progress = [System.Windows.Forms.ToolStripLabel]::new()
$Progress.Name = 'Progress'
$Progress.Text = $null
$Progress.Text = "                                                                                              "
$Progress.Width = 50
$Progress.Visible = $true

$ProgressBar = [System.Windows.Forms.ToolStripProgressBar]::new()
$ProgressBar.Name = 'ProgressBar'
$ProgressBar.Width = 50
$ProgressBar.Visible = $false

$SupportInfo = [System.Windows.Forms.ToolStripLabel]::new()
$SupportInfo.Name = 'Copyright'
$SupportInfo.Text = 'Support and Updates (Deutsch / English) @'
$SupportInfo.Width = 400
$SupportInfo.Visible = $true

$SupportLink = [System.Windows.Forms.ToolStripLabel]::new()
$SupportLink.Name = 'Support'
$SupportLink.IsLink = $true
$SupportLink.LinkBehavior = System.Windows.Forms.LinkBehavior.AlwaysUnderline
$SupportLink.Text = "https://www.guilded.gg/projectjericho"
$SupportLink.Tag = "https://www.guilded.gg/projectjericho"
$SupportLink.Width = 50
$SupportLink.Visible = $true
$SupportLink.add_Click={
    [System.Diagnostics.Process]::Start($SupportLink.Text)
}

$StatusStrip.Items.AddRange(
    [System.Windows.Forms.ToolStripItem[]]@(
        $Copyright,
        $Progress,
        $ProgressBar,
        $SupportInfo,
        $SupportLink
    )
)
$Form.Controls.Add($StatusStrip) 

#$webBrowser2 = New-Object System.Windows.Forms.WebBrowser
#$webBrowser2.IsWebBrowserContextMenuEnabled = $false
#$webBrowser2.URL = 'https://www.guilded.gg/projectjericho'
#$webBrowser2.URL = 'https://www.guilded.gg/projectjericho/groups/PdYqLpWd/channels/7c6359f8-19f6-49f2-9f13-4bf3f3262cbe/announcements'
#$webBrowser2.Width = 520
#$webBrowser2.Height = 470
#$webBrowser2.Location = “500, 130”
#$Form.Controls.Add($webBrowser2)

# SELECTION BOX1
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Location = New-Object System.Drawing.Size(20,130) 
$groupBox.size = New-Object System.Drawing.Size(200,470) 
$groupBox.text = "Destination" 
$Form.Controls.Add($groupBox) 

# SELECTION BOX2
$CheckBox = New-Object System.Windows.Forms.GroupBox
$CheckBox.Location = New-Object System.Drawing.Size(240,130) 
$CheckBox.size = New-Object System.Drawing.Size(250,470) 
$CheckBox.text = "QuantumMarker (Optional)" 
$Form.Controls.Add($CheckBox) 

##################
### LEGEND BOX ###
##################
$Legend = New-Object System.Windows.Forms.GroupBox
$Legend.Location = New-Object System.Drawing.Size(240,5) 
$Legend.size = New-Object System.Drawing.Size(250,120) 
$Legend.text = "Legend" 
$Form.Controls.Add($Legend)
# LEGEND - FIRST ENTRY
$Legend1 = New-Object System.Windows.Forms.Label 
$Legend1.Location = new-object System.Drawing.Point(21,20) 
$Legend1.size = New-Object System.Drawing.Size(100,20) 
$Legend1.ForeColor = [System.Drawing.Color]::Gray
$Legend1.Text = "No coordinates yet" 
$Legend.Controls.Add($Legend1) 
# 
$Legend2 = New-Object System.Windows.Forms.Label 
$Legend2.Location = new-object System.Drawing.Point(21,38) 
$Legend2.size = New-Object System.Drawing.Size(190,20) 
$Legend2.ForeColor = [System.Drawing.Color]::Blue
$Legend2.Text = "QuantumMarker (starting point)" 
$Legend.Controls.Add($Legend2)
# 
$Legend3 = New-Object System.Windows.Forms.Label 
$Legend3.Location = new-object System.Drawing.Point(21,56) 
$Legend3.size = New-Object System.Drawing.Size(190,20) 
$Legend3.ForeColor = [System.Drawing.Color]::Green
$Legend3.Text = "QuantumMarker (suggested)" 
$Legend.Controls.Add($Legend3) 
# 
$Legend4 = New-Object System.Windows.Forms.CheckBox 
$Legend4.Location = new-object System.Drawing.Point(5,74) 
$Legend4.size = New-Object System.Drawing.Size(170,20) 
$Legend4.Checked = $true 
#$Legend4.Enabled = $false 
$Legend4.AutoCheck = $false 
$Legend4.Text = "QuantumMarker (selected)" 
$Legend.Controls.Add($Legend4) 

#################
### LIMIT BOX ###
#################
$Limits = New-Object System.Windows.Forms.GroupBox
$Limits.Location = New-Object System.Drawing.Size(760,5) 
$Limits.size = New-Object System.Drawing.Size(250,120) 
$Limits.text = "Limits (meters)" 
$Form.Controls.Add($Limits) 

$LabelDistanceGreen = New-Object System.Windows.Forms.Label 
$LabelDistanceGreen.Location = new-object System.Drawing.Point(5,28) 
$LabelDistanceGreen.size = New-Object System.Drawing.Size(100,15) 
$LabelDistanceGreen.ForeColor = [System.Drawing.Color]::Green
$LabelDistanceGreen.Text = "Distance Green" 
$Limits.Controls.Add($LabelDistanceGreen)

$LimitDistanceGreen = New-Object System.Windows.Forms.TextBox 
$LimitDistanceGreen.Location = new-object System.Drawing.Point(150,25) 
$LimitDistanceGreen.size = New-Object System.Drawing.Size(70,20)  
$LimitDistanceGreen.ForeColor = [System.Drawing.Color]::Gray
$LimitDistanceGreen.Text = "{0:n0}" -f [Double]$DistanceGreen
$LimitDistanceGreen.TextAlign = "Right"
$Limits.Controls.Add($LimitDistanceGreen) 

$LabelDistanceYellow = New-Object System.Windows.Forms.Label 
$LabelDistanceYellow.Location = new-object System.Drawing.Point(5,48) 
$LabelDistanceYellow.size = New-Object System.Drawing.Size(100,15) 
$LabelDistanceYellow.ForeColor = [System.Drawing.Color]::Orange
$LabelDistanceYellow.Text = "Distance Yellow" 
$Limits.Controls.Add($LabelDistanceYellow)

$LimitDistanceYellow = New-Object System.Windows.Forms.TextBox 
$LimitDistanceYellow.Location = new-object System.Drawing.Point(150,45) 
$LimitDistanceYellow.size = New-Object System.Drawing.Size(70,10) 
$LimitDistanceYellow.TextAlign = "Right" 
$LimitDistanceYellow.ForeColor = [System.Drawing.Color]::Gray
$LimitDistanceYellow.Text = "{0:n0}" -f [Double]$DistanceYellow 
$Limits.Controls.Add($LimitDistanceYellow) 

$LabelQuantumGreen = New-Object System.Windows.Forms.Label 
$LabelQuantumGreen.Location = new-object System.Drawing.Point(5,68) 
$LabelQuantumGreen.size = New-Object System.Drawing.Size(100,15) 
$LabelQuantumGreen.ForeColor = [System.Drawing.Color]::Green
$LabelQuantumGreen.Text = "QuantumMarker Green" 
$Limits.Controls.Add($LabelQuantumGreen)

$LimitQuantumGreen = New-Object System.Windows.Forms.TextBox 
$LimitQuantumGreen.Location = new-object System.Drawing.Point(150,65) 
$LimitQuantumGreen.size = New-Object System.Drawing.Size(70,10) 
$LimitQuantumGreen.TextAlign = "Right" 
$LimitQuantumGreen.ForeColor = [System.Drawing.Color]::Gray
$LimitQuantumGreen.Text = "{0:n0}" -f [Double]$QMDistanceGreen
$Limits.Controls.Add($LimitQuantumGreen) 

$LabelQuantumYellow = New-Object System.Windows.Forms.Label 
$LabelQuantumYellow.Location = new-object System.Drawing.Point(5,88) 
$LabelQuantumYellow.size = New-Object System.Drawing.Size(100,15) 
$LabelQuantumYellow.ForeColor = [System.Drawing.Color]::Orange
$LabelQuantumYellow.Text = "QuantumMarker Yellow" 
$Limits.Controls.Add($LabelQuantumYellow)

$LimitQuantumYellow = New-Object System.Windows.Forms.TextBox 
$LimitQuantumYellow.Location = new-object System.Drawing.Point(150,85) 
$LimitQuantumYellow.size = New-Object System.Drawing.Size(70,10) 
$LimitQuantumYellow.TextAlign = "Right" 
$LimitQuantumYellow.ForeColor = [System.Drawing.Color]::Gray
$LimitQuantumYellow.Text = "{0:n0}" -f [Double]$QMDistanceYellow
$Limits.Controls.Add($LimitQuantumYellow) 

#####################
### 3RD PARTY BOX ###
#####################
$3rdPartyBox = New-Object System.Windows.Forms.GroupBox
$3rdPartyBox.Location = New-Object System.Drawing.Size(1020,5) 
$3rdPartyBox.size = New-Object System.Drawing.Size(200,120) 
$3rdPartyBox.text = "3rd Party Tools Autostart" 
$Form.Controls.Add($3rdPartyBox) 

# First Tool
$ToolShowLocation = New-Object System.Windows.Forms.CheckBox
$ToolShowLocation.Location = new-object System.Drawing.Point(5,20) 
$ToolShowLocation.size = New-Object System.Drawing.Size(185,20)
$ToolShowLocation.Text = "Update Location Hotkey" 
$3rdPartyBox.Controls.Add($ToolShowLocation) 

# Second Tool
$ToolAntilogoff = New-Object System.Windows.Forms.CheckBox
$ToolAntilogoff.Location = new-object System.Drawing.Point(5,40) 
$ToolAntilogoff.size = New-Object System.Drawing.Size(185,20)
$ToolAntilogoff.Text = "Anti-Logoff" 
$3rdPartyBox.Controls.Add($ToolAntilogoff) 

# Third Tool
$ToolShowOnTop = New-Object System.Windows.Forms.CheckBox
$ToolShowOnTop.Location = new-object System.Drawing.Point(5,60) 
$ToolShowOnTop.size = New-Object System.Drawing.Size(185,20)
$ToolShowOnTop.Text = "ShowOnTop" 
$3rdPartyBox.Controls.Add($ToolShowOnTop) 

# Foruth Tool
$ToolAutorun = New-Object System.Windows.Forms.CheckBox
$ToolAutorun.Location = new-object System.Drawing.Point(5,80) 
$ToolAutorun.size = New-Object System.Drawing.Size(185,20)
$ToolAutorun.Text = "AutoRun Toggle" 
$3rdPartyBox.Controls.Add($ToolAutorun) 

########################
### INSTRUCTIONS BOX ###
########################
$Instructions = New-Object System.Windows.Forms.GroupBox
$Instructions.Location = New-Object System.Drawing.Size(500,130) 
$Instructions.size = New-Object System.Drawing.Size(520,470) 
$Instructions.text = "Instructions" 
$Form.Controls.Add($Instructions)

$LiveResults = New-Object System.Windows.Forms.Label 
$LiveResults.Location = new-object System.Drawing.Point(21,20) 
$LiveResults.size = New-Object System.Drawing.Size(470,420) 
$LiveResults.ForeColor = [System.Drawing.Color]::Gray
$LiveResults.Text = "No Destination selected" 
$Instructions.Controls.Add($LiveResults) 

#$LiveResults = New-Object System.Windows.Forms.DataGridView
#$LiveResults.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
#$LiveResults.Location = new-object System.Drawing.Point(21,20) 
#$LiveResults.size = New-Object System.Drawing.Size(470,420) 
#$LiveResults.ForeColor = [System.Drawing.Color]::Gray
#$LiveResults.Text = "No Destination selected" 
#$LiveResults.Tabindex = 0
#$LiveResults.ColumnCount = 6
#$LiveResults.ColumnHeadersVisible = $True
#$LiveResults.Colums[0].Name = "Step"
#$LiveResults.Colums[1].Name = "Type"
#$LiveResults.Colums[2].Name = "Direction"
#$LiveResults.Colums[3].Name = "QuatnumMarker"
#$LiveResults.Colums[4].Name = "Jump Distance"
#$LiveResults.Colums[5].Name = "Target Distance"
$LiveResults = New-Object System.Windows.Forms.DataGridView -Property @{
    Size=New-Object System.Drawing.Size(800,400)
    ColumnHeadersVisible = $true
    }
if($FinalInstructions){$LiveResults.DataSource = $FinalInstructions}
$LiveResults.Location = new-object System.Drawing.Point(21,20) 
$LiveResults.size = New-Object System.Drawing.Size(470,420) 
$Instructions.Controls.Add($LiveResults) 

##########################
### CUSTOM COORDINATES ###
##########################
$TextBox = New-Object System.Windows.Forms.GroupBox
$TextBox.Location = New-Object System.Drawing.Size(500,5) 
$TextBox.size = New-Object System.Drawing.Size(250,120) 
$TextBox.text = "    Custom Coordinates:" 
$Form.Controls.Add($TextBox) 

# BOX3 - FIRST RADIO BUTTON
$CustomButton = New-Object System.Windows.Forms.CheckBox 
$CustomButton.Location = new-object System.Drawing.Point(3,1) 
$CustomButton.size = New-Object System.Drawing.Size(15,15)
#$CustomButton.Checked = $true 
$TextBox.Controls.Add($CustomButton) 

# X LABEL
$TextBoxLabel = New-Object System.Windows.Forms.Label
$TextBoxLabel.Location = new-object System.Drawing.Point(5,28)
$TextBoxLabel.size = New-Object System.Drawing.Size(15,15) 
$TextBoxLabel.Text = "X ="
$TextBox.Controls.Add($TextBoxLabel) 

# X INPUT
$TextBoxX = New-Object System.Windows.Forms.TextBox 
$TextBoxX.Location = new-object System.Drawing.Point(20,25) 
$TextBoxX.size = New-Object System.Drawing.Size(170,20)  
$TextBox.Controls.Add($TextBoxX) 

# Y LABEL
$TextBoxLabel = New-Object System.Windows.Forms.Label
$TextBoxLabel.Location = new-object System.Drawing.Point(5,48)
$TextBoxLabel.size = New-Object System.Drawing.Size(15,15) 
$TextBoxLabel.Text = "Y ="
$TextBox.Controls.Add($TextBoxLabel) 
# Y INPUT
$TextBoxY = New-Object System.Windows.Forms.TextBox 
$TextBoxY.Location = new-object System.Drawing.Point(20,45) 
$TextBoxY.size = New-Object System.Drawing.Size(170,20)  
$TextBox.Controls.Add($TextBoxY) 

# Z LABEL
$TextBoxLabel = New-Object System.Windows.Forms.Label
$TextBoxLabel.Location = new-object System.Drawing.Point(5,68)
$TextBoxLabel.size = New-Object System.Drawing.Size(15,15) 
$TextBoxLabel.Text = "Z ="
$TextBox.Controls.Add($TextBoxLabel) 
# Z INPUT
$TextBoxZ = New-Object System.Windows.Forms.TextBox 
$TextBoxZ.Location = new-object System.Drawing.Point(20,65) 
$TextBoxZ.size = New-Object System.Drawing.Size(170,20)  
$TextBox.Controls.Add($TextBoxZ) 

#######################
### DESTINATION BOX ###
#######################
# BOX1 - SECOND RADIO BUTTON
$ButtonDestinationJericho = New-Object System.Windows.Forms.RadioButton 
$ButtonDestinationJericho.Location = new-object System.Drawing.Point(5,20) 
$ButtonDestinationJericho.size = New-Object System.Drawing.Size(190,20) 
$ButtonDestinationJericho.Text = "Station - INS-Jericho" 
$groupBox.Controls.Add($ButtonDestinationJericho) 


# BOX1 - THIRD RADIO BUTTON
$RadioButton2 = New-Object System.Windows.Forms.RadioButton 
$RadioButton2.Location = new-object System.Drawing.Point(5,40) 
$RadioButton2.size = New-Object System.Drawing.Size(190,20) 
$RadioButton2.Text = "Wreck - Procyon" 
$groupBox.Controls.Add($RadioButton2) 

# BOX1 - THIRD RADIO BUTTON
#$RadioButton3 = New-Object System.Windows.Forms.RadioButton 
#$RadioButton3.Location = new-object System.Drawing.Point(5,60) 
#$RadioButton3.size = New-Object System.Drawing.Size(190,20)
#$RadioButton3.ForeColor = [System.Drawing.Color]::Gray
#$RadioButton3.Text = "Everus NPC Armor Printing" 
#$groupBox.Controls.Add($RadioButton3) 

# BOX1 - RADIO BUTTON
$JavelinDaymar = New-Object System.Windows.Forms.RadioButton 
$JavelinDaymar.Location = new-object System.Drawing.Point(5,60) 
$JavelinDaymar.size = New-Object System.Drawing.Size(190,20) 
$JavelinDaymar.Text = "Wreck - Javelin (Daymar)" 
$groupBox.Controls.Add($JavelinDaymar) 

# BOX1 - THIRD RADIO BUTTON
#$Reserved2 = New-Object System.Windows.Forms.RadioButton 
#$Reserved2.Location = new-object System.Drawing.Point(5,80) 
#$Reserved2.size = New-Object System.Drawing.Size(190,20)
#$Reserved2.ForeColor = [System.Drawing.Color]::Gray
#$Reserved2.Text = "Reserved" 
#$groupBox.Controls.Add($Reserved2) 

#$Reserved1 = New-Object System.Windows.Forms.RadioButton 
#$Reserved1.Location = new-object System.Drawing.Point(5,60) 
#$Reserved1.size = New-Object System.Drawing.Size(190,20)
#$Reserved1.ForeColor = [System.Drawing.Color]::Gray
#$Reserved1.Text = "Reserved" 
#$groupBox.Controls.Add($Reserved1) 

# BOX1 - RADIO BUTTON
$ShubinMiningFacilitySCD1 = New-Object System.Windows.Forms.RadioButton 
$ShubinMiningFacilitySCD1.Location = new-object System.Drawing.Point(5,100) 
$ShubinMiningFacilitySCD1.size = New-Object System.Drawing.Size(190,20) 
$ShubinMiningFacilitySCD1.Text = "Daymar - Shubin Mining" 
$groupBox.Controls.Add($ShubinMiningFacilitySCD1) 

# BOX1 - RADIO BUTTON
$EagerFlatsAidShelter = New-Object System.Windows.Forms.RadioButton 
$EagerFlatsAidShelter.Location = new-object System.Drawing.Point(5,120) 
$EagerFlatsAidShelter.size = New-Object System.Drawing.Size(190,20) 
$EagerFlatsAidShelter.Text = "Daymar - Eager Flats Aid " 
$groupBox.Controls.Add($EagerFlatsAidShelter)       

# BOX1 - RADIO BUTTON
$KudreOre = New-Object System.Windows.Forms.RadioButton 
$KudreOre.Location = new-object System.Drawing.Point(5,140) 
$KudreOre.size = New-Object System.Drawing.Size(190,20) 
$KudreOre.Text = "Daymar - Kudre Ore" 
$groupBox.Controls.Add($KudreOre) 

# BOX1 - RADIO BUTTON
$ArcCorp141 = New-Object System.Windows.Forms.RadioButton 
$ArcCorp141.Location = new-object System.Drawing.Point(5,260) 
$ArcCorp141.size = New-Object System.Drawing.Size(190,20) 
$ArcCorp141.Text = "ArcCorp Mining Area 141" 
$groupBox.Controls.Add($ArcCorp141) 

# BOX1 - RADIO BUTTON
$DunlowRidge = New-Object System.Windows.Forms.RadioButton 
$DunlowRidge.Location = new-object System.Drawing.Point(5,180) 
$DunlowRidge.size = New-Object System.Drawing.Size(190,20) 
$DunlowRidge.Text = "Dunlow Ridge Aid Shelter" 
$groupBox.Controls.Add($DunlowRidge) 

# BOX1 - RADIO BUTTON
$WolfPointAidShelter = New-Object System.Windows.Forms.RadioButton 
$WolfPointAidShelter.Location = new-object System.Drawing.Point(5,200) 
$WolfPointAidShelter.size = New-Object System.Drawing.Size(190,20) 
$WolfPointAidShelter.Text = "Wolf Point Aid Shelter" 
$groupBox.Controls.Add($WolfPointAidShelter) 

# BOX1 - RADIO BUTTON
$NuenWasteManagement = New-Object System.Windows.Forms.RadioButton 
$NuenWasteManagement.Location = new-object System.Drawing.Point(5,220) 
$NuenWasteManagement.size = New-Object System.Drawing.Size(190,20) 
$NuenWasteManagement.Text = "Nuen Waste Management" 
$groupBox.Controls.Add($NuenWasteManagement) 

# BOX1 - RADIO BUTTON
$KudreOreMine = New-Object System.Windows.Forms.RadioButton 
$KudreOreMine.Location = new-object System.Drawing.Point(5,240) 
$KudreOreMine.size = New-Object System.Drawing.Size(190,20) 
$KudreOreMine.Text = "Kudre Ore Mine" 
$groupBox.Controls.Add($KudreOreMine) 

# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox1 = New-Object System.Windows.Forms.CheckBox
$CheckBox1.Location = new-object System.Drawing.Point(5,20) 
$CheckBox1.size = New-Object System.Drawing.Size(240,20)
$CheckBox1.Text = "Planet - ArcCorp" 
$CheckBox.Controls.Add($CheckBox1) 
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox2 = New-Object System.Windows.Forms.CheckBox
$CheckBox2.Location = new-object System.Drawing.Point(5,40) 
$CheckBox2.size = New-Object System.Drawing.Size(240,20) 
$CheckBox2.Text = "Planet - Crusader" 
$CheckBox.Controls.Add($CheckBox2)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox27 = New-Object System.Windows.Forms.CheckBox
$CheckBox27.Location = new-object System.Drawing.Point(5,60) 
$CheckBox27.size = New-Object System.Drawing.Size(240,20) 
$CheckBox27.Text = "Planet - Hurston" 
$CheckBox.Controls.Add($CheckBox27)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox3 = New-Object System.Windows.Forms.CheckBox
$CheckBox3.Location = new-object System.Drawing.Point(5,80) 
$CheckBox3.size = New-Object System.Drawing.Size(240,20) 
$CheckBox3.Text = "Planet - Microtech" 
$CheckBox.Controls.Add($CheckBox3)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox4 = New-Object System.Windows.Forms.CheckBox
$CheckBox4.Location = new-object System.Drawing.Point(5,100) 
$CheckBox4.size = New-Object System.Drawing.Size(240,20) 
$CheckBox4.Text = "Moon - Delamar" 
$CheckBox.Controls.Add($CheckBox4) 
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox5 = New-Object System.Windows.Forms.CheckBox
$CheckBox5.Location = new-object System.Drawing.Point(5,120) 
$CheckBox5.size = New-Object System.Drawing.Size(240,20)
#$CheckBox5.Text = "ARC-L1 (Wide Forest)" 
$CheckBox5.Text = "Lagrange - ARC-L1" 
$CheckBox.Controls.Add($CheckBox5)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox6 = New-Object System.Windows.Forms.CheckBox
$CheckBox6.Location = new-object System.Drawing.Point(5,140) 
$CheckBox6.size = New-Object System.Drawing.Size(240,20) 
$CheckBox6.Text = "Lagrange - ARC-L2" 
#$CheckBox6.Text = "ARC-L2 (Lively Pathway Station)" 
$CheckBox.Controls.Add($CheckBox6)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox7 = New-Object System.Windows.Forms.CheckBox
$CheckBox7.Location = new-object System.Drawing.Point(5,160) 
$CheckBox7.size = New-Object System.Drawing.Size(240,20) 
$CheckBox7.Text = "Lagrange - ARC-L3" 
#$CheckBox7.Text = "ARC-L3 (Modern Express Station)" 
$CheckBox.Controls.Add($CheckBox7)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox8 = New-Object System.Windows.Forms.CheckBox
$CheckBox8.Location = new-object System.Drawing.Point(5,180) 
$CheckBox8.size = New-Object System.Drawing.Size(240,20) 
$CheckBox8.Text = "Lagrange - ARC-L4" 
#$CheckBox8.Text = "ARC-L4 (Faint Glen Station)" 
$CheckBox.Controls.Add($CheckBox8)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox9 = New-Object System.Windows.Forms.CheckBox
$CheckBox9.Location = new-object System.Drawing.Point(5,200) 
$CheckBox9.size = New-Object System.Drawing.Size(240,20) 
$CheckBox9.Text = "Lagrange - ARC-L5" 
#$CheckBox9.Text = "ARC-L5 (Yellow Core Station)" 
$CheckBox.Controls.Add($CheckBox9)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox10 = New-Object System.Windows.Forms.CheckBox
$CheckBox10.Location = new-object System.Drawing.Point(5,220) 
$CheckBox10.size = New-Object System.Drawing.Size(240,20) 
$CheckBox10.Text = "Lagrange - CRU-L1" 
#$CheckBox10.Text = "CRU-L1 (Ambitous Dream)" 
$CheckBox.Controls.Add($CheckBox10)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox11 = New-Object System.Windows.Forms.CheckBox
$CheckBox11.Location = new-object System.Drawing.Point(5,240) 
$CheckBox11.size = New-Object System.Drawing.Size(240,20) 
$CheckBox11.Text = "Lagrange - CRU-L2" 
#$CheckBox11.Text = "CRU-L2 (xxx)" 
$CheckBox11.ForeColor = [System.Drawing.Color]::Gray
$CheckBox.Controls.Add($CheckBox11)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox12 = New-Object System.Windows.Forms.CheckBox
$CheckBox12.Location = new-object System.Drawing.Point(5,260) 
$CheckBox12.size = New-Object System.Drawing.Size(240,20) 
$CheckBox12.Text = "Lagrange - CRU-L3" 
#$CheckBox12.Text = "CRU-L3 (xxx)" 
$CheckBox.Controls.Add($CheckBox12)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox13 = New-Object System.Windows.Forms.CheckBox
$CheckBox13.Location = new-object System.Drawing.Point(5,280) 
$CheckBox13.size = New-Object System.Drawing.Size(240,20) 
$CheckBox13.Text = "Lagrange - CRU-L4" 
#$CheckBox13.Text = "CRU-L4 (Shallow Fields)" 
$CheckBox.Controls.Add($CheckBox13)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox14 = New-Object System.Windows.Forms.CheckBox
$CheckBox14.Location = new-object System.Drawing.Point(5,300) 
$CheckBox14.size = New-Object System.Drawing.Size(240,20) 
$CheckBox14.Text = "Lagrange - CRU-L5" 
#$CheckBox14.Text = "CRU-L5 (Beautiful Glen)" 
$CheckBox.Controls.Add($CheckBox14)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox15 = New-Object System.Windows.Forms.CheckBox
$CheckBox15.Location = new-object System.Drawing.Point(5,320) 
$CheckBox15.size = New-Object System.Drawing.Size(240,20) 
$CheckBox15.Text = "Lagrange - HUR-L1" 
#$CheckBox15.Text = "HUR-L1 (Green Glade)" 
$CheckBox.Controls.Add($CheckBox15)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox16 = New-Object System.Windows.Forms.CheckBox
$CheckBox16.Location = new-object System.Drawing.Point(5,340) 
$CheckBox16.size = New-Object System.Drawing.Size(240,20) 
$CheckBox16.Text = "Lagrange - HUR-L2" 
#$CheckBox16.Text = "HUR-L2 (Faithful Dream)" 
$CheckBox.Controls.Add($CheckBox16)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox17 = New-Object System.Windows.Forms.CheckBox
$CheckBox17.Location = new-object System.Drawing.Point(5,360) 
$CheckBox17.size = New-Object System.Drawing.Size(240,20) 
$CheckBox17.Text = "Lagrange - HUR-L3" 
#$CheckBox17.Text = "HUR-L3 (Thundering Express)" 
$CheckBox.Controls.Add($CheckBox17)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox18 = New-Object System.Windows.Forms.CheckBox
$CheckBox18.Location = new-object System.Drawing.Point(5,380) 
$CheckBox18.size = New-Object System.Drawing.Size(240,20) 
$CheckBox18.Text = "Lagrange - HUR-L4" 
#$CheckBox18.Text = "HUR-L4 (Melodic Fields)" 
$CheckBox.Controls.Add($CheckBox18)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox19 = New-Object System.Windows.Forms.CheckBox
$CheckBox19.Location = new-object System.Drawing.Point(5,400) 
$CheckBox19.size = New-Object System.Drawing.Size(240,20) 
$CheckBox19.Text = "Lagrange - HUR-L5" 
#$CheckBox19.Text = "HUR-L5 (High Course)" 
$CheckBox.Controls.Add($CheckBox19)
# BOX2 - FIRST MULTICHOICE BUTTON
$CheckBox20 = New-Object System.Windows.Forms.CheckBox
$CheckBox20.Location = new-object System.Drawing.Point(5,420) 
$CheckBox20.size = New-Object System.Drawing.Size(240,20) 
$CheckBox20.Text = "Lagrange - MIC-L1" 
#$CheckBox20.Text = "MIC-L1 (Shallow Frontier)" 
$CheckBox.Controls.Add($CheckBox20)
# BOX2 - FIRST MULTICHOICE BUTTON
#$CheckBox26 = New-Object System.Windows.Forms.CheckBox
#$CheckBox26.Location = new-object System.Drawing.Point(5,440) 
#$CheckBox26.size = New-Object System.Drawing.Size(240,20) 
#$CheckBox26.ForeColor = [System.Drawing.Color]::Gray
#$CheckBox26.Text = "Stanton Star" 
#$CheckBox.Controls.Add($CheckBox26)

# DEFINE RUN BUTTON
$Button = New-Object System.Windows.Forms.Button 
$Button.Location = New-Object System.Drawing.Size(30,10) 
$Button.Size = New-Object System.Drawing.Size(80,40) 
$Button.Text = "RUN" 
$Form.Controls.Add($Button)


#DEFINE LOAD DESTINATION BUTTON
$Button2 = New-Object System.Windows.Forms.Button 
$Button2.Location = New-Object System.Drawing.Size(130,10) 
$Button2.Size = New-Object System.Drawing.Size(80,40) 
$Button2.Text = "Show QM" 
$Form.Controls.Add($Button2)

# DEFINE LOAD INSTRUCTIONS BUTTON
$ButtonReserved = New-Object System.Windows.Forms.Button 
$ButtonReserved.Location = New-Object System.Drawing.Size(30,60) 
$ButtonReserved.Size = New-Object System.Drawing.Size(80,40) 
$ButtonReserved.ForeColor = [System.Drawing.Color]::Gray
$ButtonReserved.Text = "Reserved" 
$Form.Controls.Add($ButtonReserved)

#DEFINE RESERVED BUTTON
$ButtonLoadInstructions = New-Object System.Windows.Forms.Button 
$ButtonLoadInstructions.Location = New-Object System.Drawing.Size(130,60) 
$ButtonLoadInstructions.Size = New-Object System.Drawing.Size(80,40) 
$ButtonLoadInstructions.ForeColor = [System.Drawing.Color]::Gray
$ButtonLoadInstructions.Text = "Load Instructions"
$Form.Controls.Add($ButtonLoadInstructions)

# ADD FUNCTION THAT CAN BE SELECTED / EXECUTED
$script:CurrentQuantumMarker = @()
$Button2.Add_Click({
    if ($ButtonDestinationJericho.Checked -eq $true) {
        $CheckBox7.ForeColor  = [System.Drawing.Color]::Green  #ARC-L3
        $CheckBox27.ForeColor  = [System.Drawing.Color]::Green #Hurston
        $CheckBox20.ForeColor = [System.Drawing.Color]::Blue   #MIC-L1
    }
    if ($RadioButton2.Checked -eq $true) {
        $CheckBox7.ForeColor  = [System.Drawing.Color]::Green  #ARC-L3
        $CheckBox27.ForeColor  = [System.Drawing.Color]::Green #Hurston
        $CheckBox20.ForeColor = [System.Drawing.Color]::Blue   #MIC-L1
    }

    
})
$Button.Add_Click({
    if ($ButtonDestinationJericho.Checked -eq $true)     {$script:CurrentDestination = "INS-Jericho"}
    if ($RadioButton2.Checked -eq $true)                 {$script:CurrentDestination = "ProcyonWreckSite"}
    if ($RadioButton3.Checked -eq $true)                 {$script:CurrentDestination = "EverusArmor"}
    if ($RadioButton4.Checked -eq $true)                 {$script:CurrentDestination = ""}
    if ($ShubinMiningFacilitySCD1.Checked -eq $true)     {$script:CurrentDestination = "Shubin Mining Facility SCD-1";$script:PlanetaryPoi = $true}
    if ($EagerFlatsAidShelter.Checked -eq $true)         {$script:CurrentDestination = "Eager Flats Aid Shelter";$script:PlanetaryPoi = $true}
    if ($KudreOre.Checked -eq $true)                     {$script:CurrentDestination = "Kudre Ore";$script:PlanetaryPoi = $true}
    if ($WolfPointAidShelter.Checked -eq $true)          {$script:CurrentDestination = "Wolf Point Aid Shelter";$script:PlanetaryPoi = $true}
    if ($NuenWasteManagement.Checked -eq $true)          {$script:CurrentDestination = "Nuen Waste Management";$script:PlanetaryPoi = $true}
    if ($JavelinDaymar.Checked -eq $true)                {$script:CurrentDestination = "Javelin (Daymar)";$script:PlanetaryPoi = $true}
    if ($KudreOreMine.Checked -eq $true)                 {$script:CurrentDestination = "Kudre Ore Mine";$script:PlanetaryPoi = $true}
    if ($ArcCorp141.Checked -eq $true)                 {$script:CurrentDestination = "ArcCorp Mining Area 141";$script:PlanetaryPoi = $true}
    if ($DunlowRidge.Checked -eq $true)                 {$script:CurrentDestination = "Dunlow Ridge Aid Shelter";$script:PlanetaryPoi = $true}
    if ($CustomButton.Checked -eq $true)                 {$script:CustomCoordsProvided = $true}

    if ($CheckBox1.Checked  -eq $true) {$script:CurrentQuantumMarker += "ArcCorp"}
    if ($CheckBox2.Checked  -eq $true) {$script:CurrentQuantumMarker += "Crusader"}
    if ($CheckBox27.Checked -eq $true) {$script:CurrentQuantumMarker += "Hurston"}
    if ($CheckBox3.Checked  -eq $true) {$script:CurrentQuantumMarker += "Microtech"}
    if ($CheckBox4.Checked  -eq $true) {$script:CurrentQuantumMarker += "Delamar"}
    if ($CheckBox5.Checked  -eq $true) {$script:CurrentQuantumMarker += "ARC-L1"}
    if ($CheckBox6.Checked  -eq $true) {$script:CurrentQuantumMarker += "ARC-L2"}
    if ($CheckBox7.Checked  -eq $true) {$script:CurrentQuantumMarker += "ARC-L3"}
    if ($CheckBox8.Checked  -eq $true) {$script:CurrentQuantumMarker += "ARC-L4"}
    if ($CheckBox9.Checked  -eq $true) {$script:CurrentQuantumMarker += "ARC-L5"}
    if ($CheckBox10.Checked -eq $true) {$script:CurrentQuantumMarker += "CRU-L1"}
    if ($CheckBox11.Checked -eq $true) {$script:CurrentQuantumMarker += "CRU-L2"}
    if ($CheckBox12.Checked -eq $true) {$script:CurrentQuantumMarker += "CRU-L3"}
    if ($CheckBox13.Checked -eq $true) {$script:CurrentQuantumMarker += "CRU-L4"}
    if ($CheckBox14.Checked -eq $true) {$script:CurrentQuantumMarker += "CRU-L5"}
    if ($CheckBox15.Checked -eq $true) {$script:CurrentQuantumMarker += "HUR-L1"}
    if ($CheckBox16.Checked -eq $true) {$script:CurrentQuantumMarker += "HUR-L2"}
    if ($CheckBox17.Checked -eq $true) {$script:CurrentQuantumMarker += "HUR-L3"}
    if ($CheckBox18.Checked -eq $true) {$script:CurrentQuantumMarker += "HUR-L4"}
    if ($CheckBox19.Checked -eq $true) {$script:CurrentQuantumMarker += "HUR-L5"}
    if ($CheckBox20.Checked -eq $true) {$script:CurrentQuantumMarker += "MIC-L1"}
    if ($CheckBox26.Checked -eq $true) {$script:CurrentQuantumMarker += "Stanton-Star"}

    if ($ToolAntilogoff.Checked   -eq $true){$script:ListOfToolsToStart += "ToolAntilogoff"}
    if ($ToolShowLocation.Checked -eq $true){$script:ListOfToolsToStart += "ToolShowLocation"}
    if ($ToolShowOnTop.Checked    -eq $true){$script:ListOfToolsToStart += "ToolShowOnTop"}
    if ($ToolAutorun.Checked      -eq $true){$script:ListOfToolsToStart += "ToolAutorun"}
    $form.Close()
    $script:StartNavigation = $true
}) 
$ButtonLoadInstructions.Add_Click({
    if ($ButtonDestinationJericho.Checked -eq $true) {
        $script:CurrentDestination = "INS-Jericho"
        $form.Close()
        $script:ReloadForm = $true
    }
})

# POPUP FORM
Show-Frontend


###################
### MAIN SCRIPT ###
###################
#DETERMINE SCRIPT PATH WITHIN VSCODE, iSE OR POWERSHELL
if($env:TERM_PROGRAM -eq "vscode"){$script:ScriptDir = $psEditor.GetEditorContext().CurrentFile.Path -replace '[^\\]+$'}
if($psISE){$script:ScriptDir = Split-Path -Path $psISE.CurrentFile.FullPath}
if((Get-Host).Version.Major -gt "5"){$script:ScriptDir = $PSScriptRoot}
else{$script:ScriptDir = $PSScriptRoot}



#START 3RD PARTY TOOLS
foreach ($Tool in $script:ListOfToolsToStart){
    switch ($Tool){
        "ToolAntiLogoff" {$3rdPartyFileName = "Autoit Scripts\AntiLogoffScript_V2.ahk"}
        "ToolShowLocation" {$3rdPartyFileName = "Showlocation_Hotkey ALT-R or LEFTCTRL+ALT_RunAsAdmin.exe"}
        "ToolShowOnTop" {$3rdPartyFileName = "WindowTop.exe"}
        "ToolAutorun" {$3rdPartyFileName = "Autoit Scripts\autorun.ahk"}
    }
    if(get-process | Where-Object {$_.path -like "*$3rdPartyFileName"} -ea SilentlyContinue){
        #Process is already running
    }
    else{Start-process -FilePath "$ScriptDir\$3rdPartyFileName"}
}


if ($ScriptLoopCount -eq 0){
    $ClipboardContent = ("Coordinates: X:0 y:0 z:0").split(":").Split(" ")
    #Add-Type -AssemblyName System.Windows.Forms
    $ScreenResolution = [System.Windows.Forms.Screen]::AllScreens
    $WindowSizeX = 25
    $WindowSizeY = 85
    $MaxX = $ScreenResolution[0].WorkingArea.Width -720 
    #$MaxY = $ScreenResolution[0].WorkingArea.Height
    Move-Window $MaxX 5
    Set-WindowSize $WindowSizeX $WindowSizeY
    Keep-ConsoleOnTop
}

#CLEAR OLD VARIABLES
$SelectedDestination = @{}

if($debug){Write-Host "Start Navigation $StartNavigation"}
#CHECK CLIPBOARD FOR NEW VALUES 
while($StartNavigation) {
    # Checks for new clipboard conents every 1 Second
    Start-Sleep 1
    if($debug){Write-Host "Main loop initiated"}

    #GET DESTINATION COORDINATES FROM HASTABLES, FILTER FOR CURRENT DESTINATION
    if($script:CustomCoordsProvided){
        if($TextBoxX.Text -and $TextBoxY.Text -and $TextBoxZ.Text){
            #SET DESTINATION TO CUSTOM COORDINATES
            $SelectedDestination = @{"Custom" = "$($TextBoxX.Text);$($TextBoxY.Text);$($TextBoxZ.Text)"}
            $DestCoordData = $SelectedDestination.Value -Split ";"
            $DestCoordDataX = $TextBoxX.Text
            $DestCoordDataY = $TextBoxY.Text
            $DestCoordDataZ = $TextBoxZ.Text
        }
        else{
            #IF COORDINATES ARE ENTERED WRONG
            $ErrorMessageCustomCoords = "Custom coordinates are missing correct values"
            Write-Host -ForegroundColor Red $ErrorMessageCustomCoords
            $LiveResults.Text = $ErrorMessageCustomCoords
            Show-Frontend
        }

    }
    
    #Advanced Color Coding
    #$esc = "$([char]27)"
    #"$ESC[48;2;255;0;123m"

    #################################################
    ### POI ON ROTATING OBJECT CONTAINER, PLANETS ###
    #################################################
    elseif($script:PlanetaryPoi){
        #GET UTC SERVER TIME
        $UTCServerTime = [DateTime](Get-Date).ToUniversalTime()  
        if ($UseTestdata){
            $UTCServerTime = [DateTime]::ParseExact('29.12.2020 14:59:00','dd.MM.yyyy HH:mm:ss',$null)
            #$UTCServerTime = [DateTime]"29.12.2020 14:59:00"  
        }
        
        #$SimulationServerStartTime = [DateTime] "01.01.2950 00:00:00"                                                # SET STARTTIME SIMULATION STARCITIZEN
        $SimulationUTCStartTime = [DateTime]"01.01.2020 00:00:00"                                                    # SET STARTTIME SIMULATION UTC
        $ElapsedUTCTimeSinceSimulationStart = New-Timespan -End $UTCServerTime -Start $SimulationUTCStartTime     # GET ELPASED TIME BETWEEN SIMULATION TIME AND CURRENT TIME
        #if ($debug){$ElapsedUTCTimeSinceSimulationStart = $UTCServerTime - $SimulationUTCStartTime}
        #$SimulationServerTime = $SimulationServerStartTime + ($ElapsedUTCTimeSinceSimulationStart * 6)            # GET ELPASED TIME SERVER SIMULATION
        #$ElapsedSimulationTimeSinceSimulationStart = New-Timespan -End $SimulationServerTime -Start $SimulationServerStartTime

        #GET ORBITAL COORDINATES
        $SelectedDestination = $PointsOfInterestOnPlanetsData.GetEnumerator() | Where-Object { $_.Key -eq $script:CurrentDestination }
        $PoiCoordData = $SelectedDestination.Value -Split ";"
        $PoiCoordDataPlanet = $PoiCoordData[0]
        $PoiCoordDataX = $PoiCoordData[1]
        $PoiCoordDataY = $PoiCoordData[2]
        $PoiCoordDataZ = $PoiCoordData[3]

        #GET THE SITES PLANET
        #$CurrentPlanet = ($PoisOnPlanetData.GetEnumerator() | Where-Object { $_.Key -eq $script:CurrentDestination }).Value

        #GET THE PLANETS COORDS IN STANTON
        #$SelectedPlanet = $PlanetData.GetEnumerator() | Where-Object { $_.Key -eq $CurrentPlanet}
        $SelectedPlanet = $PlanetData.GetEnumerator() | Where-Object { $_.Key -eq $PoiCoordDataPlanet}
        $PlanetDataParsed = $SelectedPlanet.Value -Split ";"
        $PlanetCoordDataX = $PlanetDataParsed[0]
        $PlanetCoordDataY = $PlanetDataParsed[1]
        $PlanetCoordDataZ = $PlanetDataParsed[2]
        $PlanetRotationSpeed = $PlanetDataParsed[3]
        $PlanetRotationStart = $PlanetDataParsed[4]
        $PlanetOMRadius = $PlanetDataParsed[5]

  
        #FORMULA TO CALCULATE THE CURRENT STANTON X, Y, Z COORDNIATES FROM ROTATING PLANET
        #GET CURRENT ROTATION FROM ANGLE
        $LengthOfDayDecimal = [double]$PlanetRotationSpeed * 3600 / 86400  #CORRECT
        $JulianDate = $ElapsedUTCTimeSinceSimulationStart.TotalDays        #CORRECT
        $TotalCycles = $JulianDate / $LengthOfDayDecimal                   #CORRECT
        $CurrentCycleDez = $TotalCycles%1
        $CurrentCycleDeg = $CurrentCycleDez * 360
        if (($CurrentCycleDeg + $PlanetRotationStart) -gt 360){$CurrentCycleAngle = 360 - [double]$PlanetRotationStart + [double]$CurrentCycleDeg}
        if (($CurrentCycleDeg + $PlanetRotationStart) -lt 360){$CurrentCycleAngle = [double]$PlanetRotationStart + [double]$CurrentCycleDeg}

        #CALCULATE THE RESULTING X Y COORDS 
        # /180 * PI = Conversion from 
        $PoiRotationValueX = [double]$PoiCoordDataX * ([math]::Cos($CurrentCycleAngle/180*[System.Math]::PI)) - [double]$PoiCoordDataY * ([math]::Sin($CurrentCycleAngle/180*[System.Math]::PI))
        $PoiRotationValueY = [double]$PoiCoordDataX * ([math]::Sin($CurrentCycleAngle/180*[System.Math]::PI)) + [double]$PoiCoordDataY * ([math]::Cos($CurrentCycleAngle/180*[System.Math]::PI))

        #SUBTRACT POI COORDS FROM PLANET COORDS
        $DestCoordDataX = ([double]$PlanetCoordDataX + $PoiRotationValueX) * 1000
        $DestCoordDataY = ([double]$PlanetCoordDataY + $PoiRotationValueY) * 1000
        $DestCoordDataZ = ([double]$PlanetCoordDataZ + $PoiCoordDataZ) * 1000

        $FinalPoiCoords = @{}
        $FinalPoiCoords = @{
            "$script:CurrentDestination" = "$DestCoordDataX;$DestCoordDataY;$DestCoordDataZ"
        }
        
        $FinalPlanetCoords = @{}
        $FinalPlanetDataX = [double]$PlanetCoordDataX * 1000
        $FinalPlanetDataY = [double]$PlanetCoordDataY * 1000
        $FinalPlanetDataZ = [double]$PlanetCoordDataZ * 1000
        $FinalPlanetCoords = @{
            "$CurrentPlanet" = "$FinalPlanetDataX;$FinalPlanetDataY;$FinalPlanetDataZ"
        }
        #ToDo
        #RE CALCULATE PREIOUS VALUES BASED ON ROTATION
        #CURRENTLY COURSE DIAVATION SHOWS 35° WHEN HEADING DIRECTLY TO THE TARGET. THIS IS CAUSED BY THE ROTATION AND THE PREVIOUS LOCATION NOT RECALCULATE ON ROTATIO

    }
    else{
        #SELECT DESTINATION FROM EXISTING TABLE
        $SelectedDestination = $PointsOfInterestInSpaceData.GetEnumerator() | Where-Object { $_.Key -eq $script:CurrentDestination }
        $DestCoordData = $SelectedDestination.Value -Split ";"
        $DestCoordDataX = $DestCoordData[0]
        $DestCoordDataY = $DestCoordData[1]
        $DestCoordDataZ = $DestCoordData[2]
    }
    
    if ($ScriptLoopCount -ge 1){
        $ClipboardContent = (Get-Clipboard).split(":").Split(" ") #GET CURRENT COORDS FROM CLIPBOARD
    }
    else {
        $ClipboardContent = ("Coordinates: X:0 y:0 z:0").split(":").Split(" ")
        $ScriptLoopCount ++
    }

    if ($UseTestdata -and $ScriptLoopCount -le 1){
        #$ClipboardContent = ("Coordinates: x:-18930267127.731792 y:-2610219512.783141 z:95733.918391").split(":").Split(" ")
        $ClipboardContent = ("Coordinates: x:-18930262707.175606 y:-2610486156.324643 z:-85.636127").split(":").Split(" ")
    }
    #if ($UseTestdata -and $ScriptLoopCount -eq 2){
    #    $ClipboardContent = ("Coordinates: x:-18930267127.731792 y:-2610219512.783141 z:95733.918392").split(":").Split(" ")
    #}
    
    #CHECK IF CLIPBOARD CONTAINS COORDINATES
    if ($ClipboardContent -like "Coordinates"){
        $ClipboardContainsCoordinates = $true 
        $CurrentXPosition = $ClipboardContent[3]
        $CurrentYPosition = $ClipboardContent[5]
        $CurrentZPosition = $ClipboardContent[7]
        if($debug){Write-Host "Clipboards contains coordinates"}
    }

    #CHECK IF ANY VALUE X,Y OR Z HAS CHANGED, IF NOT SKIP

    if(($CurrentXPosition -ne $PreviousXPosition -or $CurrentYPosition -ne $PreviousYPosition -or $CurrentZPosition -ne $PreviousZPosition) -and $ClipboardContainsCoordinates){
        if($debug){Write-Host "Coordinates differ from previous ones"}

    $ScriptFirstRun = $false
    if ($script:CustomCoordsProvided){
        $DestinationName = $SelectedDestination.Keys
    }
    else {
        $DestinationName = $SelectedDestination.Name
    }

    #GET CURRENT TIME AND SAVE PREVIOUS VALUES
    $CurrentTime = Get-Date
    if($PreviousTime){
        $LastUpdateRaw1 = $CurrentTime - $PreviousTime
    }
    else{
        $LastUpdateRaw1 = $Currenttime
    }
    switch ($LastUpdateRaw1){
        {$_.Hours} {$LastUpdate = '{0:00}h {1:00}min {2:00}sec' -f $LastUpdateRaw1.Hours,$LastUpdateRaw1.Minutes,$LastUpdateRaw1.Seconds; break}
        {$_.Minutes} {$LastUpdate = '{1:00}min {2:00}sec' -f $LastUpdateRaw1.Hours,$LastUpdateRaw1.Minutes,$LastUpdateRaw1.Seconds; break}
        {$_.Seconds} {$LastUpdate = '{2:00}sec' -f $LastUpdateRaw1.Hours,$LastUpdateRaw1.Minutes,$LastUpdateRaw1.Seconds; break}
    }
    if(!$env:TERM_PROGRAM -eq 'vscode') {
        Clear-Host
      }
    Write-Host "Updated: $($CurrentTime.ToString('HH:mm:ss')), last update: $LastUpdate, Destination: $DestinationName"
    

    #Total Distance Away
    #$PreviousDistanceTotalist = $curdist
    $CurrentDistanceTotal = [math]::Sqrt([math]::pow($CurrentXPosition - $DestCoordDataX,2) + [math]::pow($CurrentYPosition - $DestCoordDataY,2) + [math]::pow($CurrentZPosition - $DestCoordDataZ,2))
    $CurrentDistanceX = [math]::Sqrt([math]::pow($CurrentXPosition - $DestCoordDataX,2))
    $CurrentDistanceY = [math]::Sqrt([math]::pow($CurrentYPosition - $DestCoordDataY,2))
    $CurrentDistanceZ = [math]::Sqrt([math]::pow($CurrentZPosition - $DestCoordDataZ,2))
    
    $CurrentDistanceTotal = [Math]::abs($CurrentDistanceTotal)
    $CurrentDistanceX     = [Math]::abs($CurrentDistanceX)
    $CurrentDistanceY     = [Math]::abs($CurrentDistanceY)
    $CurrentDistanceZ     = [Math]::abs($CurrentDistanceZ)

    #GET DIFFERENCE IN DISTANCE
    #$CurrentDeltaTotal = $PreviousDistanceTotal - $CurrentDistanceTotal
    $CurrentDeltaX     = $PreviousDistanceX - $CurrentDistanceX
    $CurrentDeltaY     = $PreviousDistanceY - $CurrentDistanceY
    $CurrentDeltaZ     = $PreviousDistanceZ - $CurrentDistanceZ
    #$CurrentDeltaTotal = [math]::Sqrt([math]::pow($PreviousDistanceX - $CurrentDistanceX,2) + [math]::pow($PreviousDistanceY - $CurrentDistanceY,2) + [math]::pow($PreviousDistanceZ - $CurrentDistanceZ,2))
    #$CurrentDeltaTotal = [math]::Sqrt([math]::pow($CurrentDeltaX ,2) + [math]::pow($CurrentDeltaY,2) + [math]::pow($CurrentDeltaZ,2))
    
    $X2 = [math]::pow($CurrentDeltaX,2)
    $Y2 = [math]::pow($CurrentDeltaY,2)
    $Z2 = [math]::pow($CurrentDeltaZ,2)
    if ($CurrentDeltaX -lt 0){$X2 = $X2 * -1}
    if ($CurrentDeltaY -lt 0){$Y2 = $Y2 * -1}
    if ($CurrentDeltaZ -lt 0){$Z2 = $Z2 * -1}

    $CurrentDeltaTotal = [math]::Sqrt([math]::Abs($X2 + $Y2 + $Z2))
    if (($X2 + $Y2 + $Z2) -lt 0){$CurrentDeltaTotal = $CurrentDeltaTotal * -1}
    #$CurrentDeltaTotal


    #OUTPUT TO USER
    # Distance Indicator KM M Delta
    $Results = @()
    $Total = "" | Select-Object Type,Distance,Delta # Spacer1, Spacer2
    $Total.Type = "Total"
    #$Total.Indicator = $StatusIndicatorT
    $Total.Distance = $CurrentDistanceTotal
    $Total.Delta = $CurrentDeltaTotal
    #$Total.Spacer1 = " "
    #$Total.Spacer2 = " "
    $Results += $Total

    $X = "" | Select-Object Type,Distance,Delta # Spacer1, Spacer2
    $X.Type = "X-Axis"
    #$X.Indicator = $StatusIndicatorX
    $X.Distance = $CurrentDistanceX
    $X.Delta = $CurrentDeltaX
    #$X.Spacer1 = " "
    #$X.Spacer2 = " "
    $Results += $X

    $Y = "" | Select-Object Type,Distance,Delta # Spacer1, Spacer2
    $Y.Type = "Y-Axis"
    #$Y.Indicator = $StatusIndicatorY
    $Y.Distance = $CurrentDistanceY
    $Y.Delta = $CurrentDeltaY
    #$Y.Spacer1 = " "
    #$Y.Spacer2 = " "
    $Results += $Y

    $Z = "" | Select-Object Type,Distance,Delta # Spacer1, Spacer2
    $Z.Type = "Z-Axis"
    #$Z.Indicator = $StatusIndicatorZ
    $Z.Distance = $CurrentDistanceZ
    $Z.Delta = $CurrentDeltaZ
    #$Z.Spacer1 = " "
    #$Z.Spacer2 = " "
    $Results += $Z
    
    #######################
    ### GENERATE OUTPUT ###
    #######################
    if(!$Powershellv5Legacy){
        $EscapeCharacter = ([char]27)                                           #EXCAPE CHARACTER TO COLORIZE TABLE
        #DEFINE VIRTUAL TERMINAL SEQUENZCE COLOR
        $VTFontRed = "91"         #Light Red
        #$VTFontDarkRed = "31"     #Dark Red
        $VTFontYellow = "93"      
        #$VTFontDarkYellow = "33"  
        $VTFontGreen = "92"
        #$VTFontDarkGreen = "32"
        $VTFontBlue = "94"
        #$VTFontDarkBlue = "34"
        $VTFontGray = "38"        #Gray, Named as Extened Colour
        $VTFontDefault = "0"      #White Text Color
        #$VTFontBolt = "1"
        #$VTFontExtened = "38"
        $VTFontDarkGray = "90"
        #$Testcolor = $VTFontDarkGray
        #"$EscapeCharacter[${Testcolor}mTest"

        #Combine String
        $VTRed = "$EscapeCharacter[${VTFontRed}m"
        $VTYellow = "$EscapeCharacter[${VTFontYellow}m"
        $VTGreen = "$EscapeCharacter[${VTFontGreen}m"
        $VTBlue = "$EscapeCharacter[${VTFontBlue}m"
        $VTGray = "$EscapeCharacter[${VTFontGray}m"
        $VTDarkGray = "$EscapeCharacter[${VTFontDarkGray}m"
        $VTDefault = "$EscapeCharacter[${VTFontDefault}m"
    }
    else{
        $EscapeCharacter = ""
        $VTGray = ""
        $VTRed = ""
        $VTYellow = ""
        $VTGreen = ""
        $VTGray = ""
        $VTDarkGray = ""
        $VTDefault = ""
    }


    $Results | Format-Table @{                                             
        Label ="$($VTDefault)Type";
        Expression ={"$($VTDefault)$($_.Type)      "}
    },
    @{
        Label = "$($VTDefault)Distance";                                  #NAME OF RESULTHEADING
        Expression = {switch ($_.Distance){                                 #COLORIZE DISTANCE BY LIMITS
            {$_ -le $DistanceGreen}  { $color = $VTGreen; break }               # When $_ is -1 its lwoer than 0 
            {$_ -le $DistanceYellow} { $color = $VTYellow; break }               #
            default { $color = $VTRed }                                       #
        }
        $DistanceTKM = [math]::Truncate($_.Distance/1000).ToString('N0')+"km"   #CONVERT DISTANCE IN KM
        $DistanceTM = ($_.Distance/1000).ToString('N3').split(',')[1]+"m "   #CONVERT DISTANCE IN M
        "$($color)$("$DistanceTKM $DistanceTM")"                          #RESULT COLOR FORMAT
        };

        #ALIGN NUMBERS TO THE RIGHT
        align ='right';
        width = 20
    },
    @{
        #Label = 'Delta';
        Label = "$($VTDefault)Delta";
        Expression = {switch ($_.Delta){
            {$_ -lt 0} { $color = $VTRed; break }     # COLOR RED IF WE GOT MORE FAR WAY
            {$_ -gt 0} { $color = $VTGreen; break }   # COLOR GREEN IF WE GOT CLOSER
            default { $color = $VTDefault }          # COLOR GRAY IF NOTHING CHANGED
        }
        $DeltaTotalKM  = [math]::Truncate($_.Delta/1000).ToString('N0')+"km"
        $DeltaTotalM   = ($_.Delta/1000).ToString('N3').split(',')[1]+"m "
        "    $($color)$("$DeltaTotalKM $DeltaTotalM")"
        };
        align = 'right'
    }
    

    ########################################
    ### SHOW DISTANCE TO QUaNTUM MARKERS ###
    ########################################
    $QMResults = @()
    foreach ($Marker in $script:CurrentQuantumMarker){
        $SelectedQuantumMarker = $QuantummarkerData.GetEnumerator() | Where-Object { $_.Key -eq $Marker }
        $QuantumMarkerCoords = $SelectedQuantumMarker.Value -Split ";"
        $QuantumMarkerDataX = $QuantumMarkerCoords[0]
        $QuantumMarkerDataY = $QuantumMarkerCoords[1]
        $QuantumMarkerDataZ = $QuantumMarkerCoords[2]
        $QuantumMarkerName = $SelectedQuantumMarker.Name -Split ";"

        #GET DISTANCES
        $QMDistanceFinal = [math]::Sqrt([math]::pow($QuantumMarkerDataX - $DestCoordDataX,2) + [math]::pow($QuantumMarkerDataY - $DestCoordDataY,2) + [math]::pow($QuantumMarkerDataZ - $DestCoordDataZ,2))
        $QMDistFinalKM = [math]::Truncate($QMDistanceFinal/1000).ToString('N0')+"km"               
        $QMDistFinalM  = ($QMDistanceFinal/1000).ToString('N3').split(',')[1]+"m" 

        #CONVERT DISTANCES IN KM AN DM
        $QMDistanceCurrent = [math]::Sqrt([math]::pow($CurrentXPosition - $QuantumMarkerDataX,2) + [math]::pow($CurrentYPosition - $QuantumMarkerDataY,2) + [math]::pow($CurrentZPosition - $QuantumMarkerDataZ,2))
        $QMDistCurrentKM = [math]::Truncate($QMDistanceCurrent/1000).ToString('N0')+"km"               
        $QMDistCurrentM  = ($QMDistanceCurrent/1000).ToString('N3').split(',')[1]+"m"   
        
        #$QMDistanceFinal - $QMDistanceCurrent
        #([Math]::abs($QMDistanceFinal - $_))
        #([Math]::abs(($QMDistanceFinal - $_)) -lt $QMDistanceGreen)
        #(([Math]::abs($QMDistanceFinal - $_)) -lt $QMDistanceYellow)

        switch ($QMDistanceCurrent){                                 #COLORIZE DISTANCE BY LIMITS
            {([Math]::abs($QMDistanceFinal - $_)) -lt $QMDistanceGreen}  { $QMcolor = $VTGreen; break } #92
            {([Math]::abs($QMDistanceFinal - $_)) -lt $QMDistanceYellow} { $QMcolor = $VTYellow; break }
            default { $QMcolor = $VTRed } #91
        }

        #switch ($QMDistanceCurrent){                                 #COLORIZE DISTANCE BY LIMITS
        #    {([Math]::abs($_) -lt $QMDistanceGreen)}  { $QMcolor = $VTFontGreen; break  } #92
        #    {([Math]::abs($_) -lt $QMDistanceYellow)} { $QMcolor = $VTFontYellow; break }
        #    default { write-host "3" } #91
        #}
        #$QMcolor

        #OUTPUT TO USER
        $QMCurrent = "" | Select-Object QuantumMarker,Current,Final
        $QMCurrent.QuantumMarker = "$QuantumMarkerName"
        $QMCurrent.Current = "${QMcolor}$("$QMDistCurrentKM $QMDistCurrentM")"
        $QMCurrent.Final = "     $([char]27)[92m$QMDistFinalKM $QMDistFinalM"
        $QMResults += $QMCurrent
    }
    $QMResults | Format-Table


    ################
    ### xabdiben ###
    ################
    function CalcDistance3d {
        Param ($x1, $y1, $z1, $x2, $y2, $z2)
        Return [math]::Sqrt(($x1 - $x2) * ($x1 - $x2) + ($y1 - $y2) * ($y1 - $y2) + ($z1 - $z2) * ($z1 - $z2) )
        }

    if ($PreviousXPosition -ne $null) {
        $xu = (($DestCoordDataX - $PreviousXPosition) * ($CurrentXPosition - $PreviousXPosition))+(($DestCoordDataY - $PreviousYPosition) * ($CurrentYPosition - $PreviousYPosition))+(($DestCoordDataZ - $PreviousZPosition) * ($CurrentZPosition - $PreviousZPosition))

        $xab_dist = CalcDistance3d $CurrentXPosition $CurrentYPosition $CurrentZPosition $PreviousXPosition $PreviousYPosition $PreviousZPosition 

        if ($xab_dist -lt 1) {
            $xab_dist=1
        }

        $xu = $xu/($xab_dist * $xab_dist)

        $closestX = [double]$PreviousXPosition + [double]$xu * ($CurrentXPosition - $PreviousXPosition)
        $closestY = [double]$PreviousYPosition + [double]$xu * ($CurrentYPosition - $PreviousYPosition)
        $closestZ = [double]$PreviousZPosition + [double]$xu * ($CurrentZPosition - $PreviousZPosition)

        #$c1 = CalcDistance3d $DestCoordDataX $DestCoordDataY $DestCoordDataZ $PreviousXPosition $PreviousYPosition $PreviousZPosition
        $c2 = CalcDistance3d $DestCoordDataX $DestCoordDataY $DestCoordDataZ $CurrentXPosition $CurrentYPosition $CurrentZPosition


        $pathError = CalcDistance3d $DestCoordDataX $DestCoordDataY $DestCoordDataZ $closestX $closestY $closestZ
        #Write-Host "Path Error = $pathError"
        $perrd = [math]::atan2($pathError, $c2) * 180.0 / [math]::pi
        $FinalAngle = [math]::Round($perrd,2)

        switch ($FinalAngle){
            {$_ -le 0.1} { $FAcolor = $VTBlue; break }
            {$_ -le 3} { $FAcolor = $VTGreen; break }
            {$_ -le 10} { $FAcolor = $VTYellow; break }
            {$_ -gt 10} { $FAcolor = $VTRed; break }
            default { $FAcolor = $VTGray }
        }
        Write-Host "Course deviation = ${FAcolor}$("$FinalAngle°") ${VTDefault}(Previous: $PreviousAngle °)"
        if($CurrentDeltaTotal -gt 0 -OR $CurrentDeltaTotal -lt 0){
            if($PreviousTime -gt 0){$CurrentETA = $CurrentDistanceTotal/($CurrentDeltaTotal/($CurrentTime - $PreviousTime).TotalSeconds)}
        }
        if($CurrentETA -gt 0){
            $ts =  [timespan]::fromseconds($CurrentETA)
            Write-Host "ETA = $($ts.Days) Days $($ts.Hours) Hours $($ts.Minutes) Minutes $($ts.Seconds) Seconds"
        }
        else {
            Write-Host -ForegroundColor Red "ETA = Wrong way Pilot, turn around."
        }
    }

    ####################
    ### INSTRUCTIONS ###
    ####################
    #GET DISTANCES FROM ALL AVAIlABLE QM
    $AllQMResults = @()
    $FinalCoordArray = @{}
    $FirstCoordArray = @{}
    $Selection = @{}

    $Selection = $PointsOfInterestInSpaceData.GetEnumerator() | Where-Object {$_.Name -contains $SelectedDestination.Name}
    $FinalCoordArray += $QuantummarkerData  # ADD ALL QUANTUM MARKER TO FINAL ARRAY
    $FirstCoordArray += $FinalCoordArray    # ADD ALL QUANTUM MARKER TO FIRST ARRAY TO DETERMINE STARTPOINT
    $FirstCoordArray += $RestStopData       # ADD ALL RESTSTOPS TO FIRST ARRAY, THEY MIGHT COME IN HANDY AS STARTING POINT
    if($script:PlanetaryPoi){$FirstCoordArray += $FinalPoiCoords}
    if($script:PlanetaryPoi){$FirstCoordArray += $FinalPlanetCoords}

    #GET ALL COORDS FROM ALL QUNATUM MARKER AND SELECTED DESTINATION
    #foreach ($QMEntry in $FinalCoordArray.GetEnumerator()){
    foreach ($QMEntry in $FirstCoordArray.GetEnumerator()){
        $InstQuantumMarkerCoords = $QMEntry.Value -Split ";"
        $InstQuantumMarkerDataX  = $InstQuantumMarkerCoords[0]
        $InstQuantumMarkerDataY  = $InstQuantumMarkerCoords[1]
        $InstQuantumMarkerDataZ  = $InstQuantumMarkerCoords[2]

        $InstQMCurrent = "" | Select-Object QuantumMarker,X,Y,Z
        $InstQMCurrent.QuantumMarker = $QMEntry.Name
        $InstQMCurrent.X = $InstQuantumMarkerDataX
        $InstQMCurrent.Y = $InstQuantumMarkerDataY
        $InstQMCurrent.Z = $InstQuantumMarkerDataZ
        $AllQMResults += $InstQMCurrent
    }

    #CALCULATE DISTANCES BETWEEN ALLE ENTRIES FROM PREVIOUS ARRAY
    $AllQMDistances = @()
    foreach ($QMEntry in $AllQMResults.GetEnumerator()){
        foreach ($Entry in $AllQMResults.GetEnumerator()){
            $DistanceBetweenQM = [math]::Sqrt([math]::pow($QMEntry.X - $Entry.X,2) + [math]::pow($QMEntry.Y - $Entry.Y,2) + [math]::pow($QMEntry.Z - $Entry.Z,2))
            $DistanceBetweenQMX = [math]::Sqrt([math]::pow($QMEntry.X - $Entry.X,2))
            $DistanceBetweenQMY = [math]::Sqrt([math]::pow($QMEntry.Y - $Entry.Y,2))
            $DistanceBetweenQMZ = [math]::Sqrt([math]::pow($QMEntry.Z - $Entry.Z,2))
            $CurrentQMDistance = "" | Select-Object QuantumMarkerFrom,QuantumMarkerTo,Distance,DistanceX,DistanceY,DistanceZ
            $CurrentQMDistance.QuantumMarkerFrom = $QMEntry.QuantumMarker
            $CurrentQMDistance.QuantumMarkerTo = $Entry.QuantumMarker
            $CurrentQMDistance.Distance = $DistanceBetweenQM
            $CurrentQMDistance.DistanceX = $DistanceBetweenQMX
            $CurrentQMDistance.DistanceY = $DistanceBetweenQMY
            $CurrentQMDistance.DistanceZ = $DistanceBetweenQMZ
            $AllQMDistances += $CurrentQMDistance
        }
    }

    #FILTER FOR CLOSEST QM TO START FROM
    $AllQMDistancesSorted = $AllQMDistances | Where-Object {$_.Distance -ne 0} 
    $QMDistancesCurrent = $AllQMDistancesSorted | Where-Object {$_.QuantumMarkerFrom -contains $SelectedDestination.Name} 
    $ClosestQMStart = $QMDistancesCurrent | Sort-Object -Property Distance | Select-Object -First 1
    
    if ($script:PlanetaryPoi) {
        $OM1 = $OM2 = $OM3 = $OM4 = $OM5 = $OM6 = ""
        #$PlanetOMRadius = ($HashtableOmRadius.GetEnumerator() | Where-Object {$_.Name -eq "$CurrentPlanet"}).Value
        $PosX = [double]$PoiCoordDataX * 1000
        $PosY = [double]$PoiCoordDataY * 1000
        $PosZ = [double]$PoiCoordDataZ * 1000
        $OM1 = [math]::Pow(([math]::Pow("$PosX","2") + [math]::Pow("$PosY","2") + [math]::Pow($PosZ-$PlanetOMRadius,"2")),1/2)
        $OM1 = [math]::Round($OM1)
        $OM2 = [math]::Pow(([math]::Pow("$PosX","2") + [math]::Pow("$PosY","2") + [math]::Pow($PosZ-(-$PlanetOMRadius),"2")),1/2)
        $OM2 = [math]::Round($OM2)
        $OM3 = [math]::Pow(([math]::Pow("$PosX","2") + [math]::Pow($PosY-$PlanetOMRadius,"2") + [math]::Pow($PosZ,"2")),1/2)
        $OM3 = [math]::Round($OM3)
        $OM4 = [math]::Pow(([math]::Pow("$PosX","2") + [math]::Pow($PosY-(-$PlanetOMRadius),"2") + [math]::Pow($PosZ,"2")),1/2)
        $OM4 = [math]::Round($OM4)
        $OM5 = [math]::Pow(([math]::Pow($PosX-$PlanetOMRadius,"2") + [math]::Pow("$PosY","2") + [math]::Pow($PosZ,"2")),1/2)
        $OM5 = [math]::Round($OM5)
        $OM6 = [math]::Pow(([math]::Pow($PosX-(-$PlanetOMRadius),"2") + [math]::Pow("$PosY","2") + [math]::Pow($PosZ,"2")),1/2)
        $OM6 = [math]::Round($OM6)

        #SORT ORBITAL MARKERS BY DISTANCE
        $OmArray = @{}
        $OmArray.add("OM1",$OM1);$OmArray.add("OM2",$OM2);$OmArray.add("OM3",$OM3);$OmArray.add("OM4",$OM4);$OmArray.add("OM5",$OM5);$OmArray.add("OM6",$OM6)

        #GET CLOSEST ORBITAL MARKER
        $OMGSStart = ($OmArray.GetEnumerator() | Sort-Object Value | Select-Object -First 1).Name
        #$OMForAngles = ($OmArray.GetEnumerator() | Where-Object {$_.Key -ne "OM1" -AND  $_.Key -ne "OM2"} | Sort-Object Value | Select-Object -First 1).Name
        $OMGSDistanceToDestination = ($OmArray.GetEnumerator() | Sort-Object Value | Select-Object -First 1).Value

        #COUSRE ALTERNATIVE CALC
        $PercentageRange = $CurrentDistanceTotal/$CurrentDeltaTotal
        $PercentageChanges = ($CurrentDistanceX/$CurrentDeltaX) - ($CurrentDistanceY/$CurrentDeltaY)
        $XPercentageRange = $PercentageRange /180*[math]::PI
        $XPercentageChanges = $PercentageChanges /180*[math]::PI
        $XCourseDiavation = ($PercentageRange * $PercentageChanges)/180*[math]::PI
        $XXCourseDiavation = ($XPercentageRange * $XPercentageChanges)/180*[math]::PI
    }

    #########################################
    ### SET ANGLE AN ALIGNMENT FOR ANGLES ###
    #########################################
    if($UseTestdata){
        #Destination
        #North = Wolf Point, Nuen Waste, Dunlow Ridge
        #South = ArcCorp 141,
        #NorthBehind = Shubin SCD1, Eager Flats
        #SouthBehind = Kudre Ore, Bountiful, Tandom
        #ShipPosition = Directly OM3
        $DistanceShipToPlanetAlignment = 429533
        $ShipRotationValueX1 = 0.092
        $ShipRotationValueY1 = 428.767
        $ShipRotationValueZ1 = -0.611
        $CurrentZPosition =  / 1000
        $PoiCoordDataX = -4.42
        $PoiCoordDataY = 279.067
        $PoiCoordDataZ = 95.733
        $DistanceShipToPlanetAlignment = 429533
        $ShipRotationValueX1 = -1.352
        $ShipRotationValueY1 = 280.932
        $ShipRotationValueZ1 = 0
        $PoiCoordDataX = -51.85
        $PoiCoordDataY = 280.932
        $PoiCoordDataZ = 75.331
    }

    #CONVERT CURRENT STANTON XYZ INTO PLANET XYZ
    $X2 = $CurrentXPosition / 1000
    $Y2 = $CurrentYPosition / 1000
    $A2 = ($PlanetCoordDataX - $X2)
    $B2 = ($PlanetCoordDataY - $Y2) 
    $ReversedAngle = 360 - $CurrentCycleAngle
    $AngleRadian = $ReversedAngle/180*[System.Math]::PI
    $ShipRotationValueX1 = ([double]$A2 * ([math]::Cos($AngleRadian)) - [double]$B2 * ([math]::Sin($AngleRadian))) * -1
    $ShipRotationValueY1 = ([double]$A2 * ([math]::Sin($AngleRadian)) + [double]$B2 * ([math]::Cos($AngleRadian))) * -1
    $ShipRotationValueZ1 = $CurrentZPosition / 1000

    # DISPLAY RESULTS FROM DESTINATION AND SHIP PLANET COORDS
    if($debug){
        "Current Ship X Coord = " + [math]::Round($ShipRotationValueX1, 3)
        "Current Ship Y Coord = " + [math]::Round($ShipRotationValueY1, 3)
        "Current Ship Z Coord = " + [math]::Round($ShipRotationValueZ1, 3)
        "$CurrentDestination X Coord = " + [math]::Round($PoiCoordDataX, 3)
        "$CurrentDestination Y Coord = " + [math]::Round($PoiCoordDataY, 3)
        "$CurrentDestination Z Coord = " + [math]::Round($PoiCoordDataZ, 3)
    }

    #DETERMINE CLOST CURRENT OM FOR ANGLE CALCULATIONS
    $OMShip1 = $OMShip2 = $OMShip3 = $OMShip4 = $OMShip5 = $OMShip6 = ""
    #$PlanetOMRadius = ($HashtableOmRadius.GetEnumerator() | Where-Object {$_.Name -eq "$CurrentPlanet"}).Value
    $PosShipX = [double]$ShipRotationValueX1 * 1000
    $PosShipY = [double]$ShipRotationValueY1 * 1000
    $PosShipZ = [double]$ShipRotationValueZ1 * 1000
    $ShipOM1 = [math]::Pow(([math]::Pow("$PosShipX","2") + [math]::Pow("$PosShipY","2") + [math]::Pow($PosShipZ-$PlanetOMRadius,"2")),1/2)
    $ShipOM1 = [math]::Round($ShipOM1)
    $ShipOM2 = [math]::Pow(([math]::Pow("$PosShipX","2") + [math]::Pow("$PosShipY","2") + [math]::Pow($PosZ-(-$PlanetOMRadius),"2")),1/2)
    $ShipOM2 = [math]::Round($ShipOM2)
    $ShipOM3 = [math]::Pow(([math]::Pow("$PosShipX","2") + [math]::Pow($PosShipY-$PlanetOMRadius,"2") + [math]::Pow($PosShipZ,"2")),1/2)
    $ShipOM3 = [math]::Round($ShipOM3)
    $ShipOM4 = [math]::Pow(([math]::Pow("$PosShipX","2") + [math]::Pow($PosShipY-(-$PlanetOMRadius),"2") + [math]::Pow($PosShipZ,"2")),1/2)
    $ShipOM4 = [math]::Round($ShipOM4)
    $ShipOM5 = [math]::Pow(([math]::Pow($PosShipX-$PlanetOMRadius,"2") + [math]::Pow("$PosShipY","2") + [math]::Pow($PosShipZ,"2")),1/2)
    $ShipOM5 = [math]::Round($ShipOM5)
    $ShipOM6 = [math]::Pow(([math]::Pow($PosShipX-(-$PlanetOMRadius),"2") + [math]::Pow("$PosShipY","2") + [math]::Pow($PosShipZ,"2")),1/2)
    $ShipOM6 = [math]::Round($ShipOM6)

    #SORT ORBITAL MARKERS BY DISTANCE
    $ShipOmArray = @{}
    $ShipOmArray.add("OM1",$ShipOM1);$ShipOmArray.add("OM2",$ShipOM2);$ShipOmArray.add("OM3",$ShipOM3);$ShipOmArray.add("OM4",$ShipOM4);$ShipOmArray.add("OM5",$ShipOM5);$ShipOmArray.add("OM6",$ShipOM6)

    #GET CLOSEST ORBITAL MARKER
    $ShipOMClosest = ($ShipOmArray.GetEnumerator() | Sort-Object Value | Select-Object -First 1).Name

    $DistanceShipToPlanetAlignment = [math]::Sqrt([math]::pow(($CurrentXPosition - $FinalPlanetDataX),2) + [math]::pow(($CurrentYPosition - $FinalPlanetDataY),2) + [math]::pow(($CurrentZPosition - $FinalPlanetDataZ),2))
    $DistancePoiToPlanet = [math]::Sqrt([math]::pow($DestCoordDataX - ([double]$PlanetCoordDataX * 1000),2) + [math]::pow($DestCoordDataY - ([double]$PlanetCoordDataY * 1000),2) + [math]::pow($DestCoordDataZ - ([double]$PlanetCoordDataZ * 1000),2))
    #$ClosestQM = $QMDistancesCurrent | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMStart.QuantumMarkerTo} | Sort-Object -Property Distance | Select-Object -First 1 

    if($ShipOMClosest -eq "OM3" -OR $ShipOMClosest -eq "OM4"){     
        $TriangleYB = [double]$PoiCoordDataY - [double]$ShipRotationValueY1
        $TriangleYA = [double]$PoiCoordDataZ - [double]$ShipRotationValueZ1
        $TriangleYC = [math]::Sqrt([math]::pow($TriangleYA,2) + [math]::pow($TriangleYB,2)) 
        $TriangleYAlpha = [math]::ASin($TriangleYA / $TriangleYC) * 180 / [System.Math]::PI         
        $TriangleYAlpha 

        $TriangleXA = $ShipRotationValueX1 + $PoiCoordDataX                                  
        $TriangleXB = [double]$PoiCoordDataY - [double]$ShipRotationValueY1                                                          
        $TriangleXC = [math]::Sqrt([math]::pow($TriangleXA,2) + [math]::pow($TriangleXB,2))  
        if($ShipOMClosest -eq "OM3"){$TriangleXAlpha = [math]::Sin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI * -1} 
        if($ShipOMClosest -eq "OM4"){$TriangleXAlpha = [math]::Sin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI} 
        if($TriangleXAlpha -lt 0){$TriangleXAlpha = 360 + $TriangleXAlpha}

        $FinalHorizontalAngle = [Math]::Round($TriangleXAlpha)
        $FinalVerticalAngle = [Math]::Round($TriangleYAlpha)

        Write-Host "Planet: ${VTGreen}$($SelectedPlanet.Name)${VTDefault}, Orbital Marker: ${VTGreen}$ShipOMClosest${VTDefault}, Alignment: ${VTGreen}Planet Centre"
        Write-Host "Planetary Angle: ${VTGreen}$FinalVerticalAngle°${VTDefault} (Vertical)"
        Write-Host "Planetary Angle: ${VTGreen}$FinalHorizontalAngle°${VTDefault} (Horizontal)"
    }

    if($ShipOMClosest -eq "OM5" -OR $ShipOMClosest -eq "OM6"){       
        if($ShipOMClosest -eq "OM6"){$TriangleYA = [double]$PoiCoordDataZ + [double]$ShipRotationValueZ1}
        $TriangleYA = [double]$PoiCoordDataZ - [double]$ShipRotationValueZ1
        if($ShipOMClosest -eq "OM6"){$TriangleYA = [double]$PoiCoordDataZ - [double]$ShipRotationValueZ1}
        $TriangleYB = [double]$PoiCoordDataX - [double]$ShipRotationValueX1
        $TriangleYC = [math]::Sqrt([math]::pow($TriangleYA,2) + [math]::pow($TriangleYB,2)) 
        $TriangleYAlpha = [math]::ASin($TriangleYA / $TriangleYC) * 180 / [System.Math]::PI         
        $TriangleYAlpha 

        $TriangleXA = [double]$PoiCoordDataY - [double]$ShipRotationValueY1                                     
        $TriangleXB = [double]$PoiCoordDataX - [double]$ShipRotationValueX1                                                             
        $TriangleXC = [math]::Sqrt([math]::pow($TriangleXA,2) + [math]::pow($TriangleXB,2))        
        $TriangleXAlpha = [math]::ASin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI
        if($ShipOMClosest -eq "OM5"){$TriangleXAlpha = [math]::ASin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI} 
        if($ShipOMClosest -eq "OM6"){$TriangleXAlpha = [math]::ASin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI * -1}   
        if($TriangleXAlpha -lt 0){$TriangleXAlpha = 360 + $TriangleXAlpha}
        $TriangleXAlpha

        $FinalHorizontalAngle = [Math]::Round($TriangleXAlpha)
        $FinalVerticalAngle = [Math]::Round($TriangleYAlpha)

        Write-Host "Planet: ${VTGreen}$($SelectedPlanet.Name)${VTDefault}, Orbital Marker: ${VTGreen}$ShipOMClosest${VTDefault}, Alignment: ${VTGreen}Planet Centre"
        Write-Host "Planetary Angle: ${VTGreen}$FinalVerticalAngle°${VTDefault} (Vertical)"
        Write-Host "Planetary Angle: ${VTGreen}$FinalHorizontalAngle°${VTDefault} (Horizontal)"
    }

    if($ShipOMClosest -eq "OM2" -OR $ShipOMClosest -eq "OM1"){                                      
        $TriangleYA = [double]$PoiCoordDataY - [double]$ShipRotationValueY1
        $TriangleYB = [double]$PoiCoordDataZ - [double]$ShipRotationValueZ1
        $TriangleYC = [math]::Sqrt([math]::pow($TriangleYA,2) + [math]::pow($TriangleYB,2)) 
        $TriangleYAlpha = [math]::ASin($TriangleYA / $TriangleYC) * 180 / [System.Math]::PI         

        $TriangleXA = [double]$PoiCoordDataX - [double]$ShipRotationValueX1                                      
        $TriangleXB = [double]$PoiCoordDataZ - [double]$ShipRotationValueZ1                                                           
        $TriangleXC = [math]::Sqrt([math]::pow($TriangleXA,2) + [math]::pow($TriangleXB,2))        
        if($ShipOMClosest -eq "OM1"){$TriangleXAlpha = [math]::ASin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI}
        if($ShipOMClosest -eq "OM2"){$TriangleXAlpha = [math]::ASin($TriangleXA / $TriangleXC) * 180 / [System.Math]::PI * -1}
        if($TriangleXAlpha -lt 0){$TriangleXAlpha = 360 + $TriangleXAlpha}

        $FinalHorizontalAngle = [Math]::Round($TriangleXAlpha)
        $FinalVerticalAngle = [Math]::Round($TriangleYAlpha)

        Write-Host "Planet: ${VTGreen}$($SelectedPlanet.Name)${VTDefault}, Orbital Marker: ${VTGreen}$ShipOMClosest${VTDefault}"
        Write-Host "Alignment Nose: ${VTGreen}Planet Centre${VTDefault}, Alignment Wings: ${VTGreen}OM5-6${VTDefault}, Top: ${VTGreen}OM-3"
        Write-Host "Planetary Angle: ${VTGreen}$FinalVerticalAngle°${VTDefault} (Vertical)"
        Write-Host "Planetary Angle: ${VTGreen}$FinalHorizontalAngle°${VTDefault} (Horizontal)"
    }


    #Minign Area 141
    #       H   V       Status
    #OM1    359 15      Correct, Correct #2
    #OM2    6   43      Correct, Correct #2
    #OM3    4   -43     Correct, Correct #2
    #OM4    359 -21     Correct, Correct #2
    #OM5    22  -26     Correct (2° Diavation Vert), Correct #2 (2° Diavation Vert)
    #OM6    336 -27     Correct (2° Diavation Vert), Correct #2 (2° Diavation Hori, (4° Diavation Vert))

    ##################################
    ### ANGLES FOR GROUND VEHICLES ###
    ##################################
    # a = total distance travelled between current and last point
    $TriangleGroundA = [math]::Sqrt(([math]::pow($PerviousShipRotationValueX1,2) - [math]::pow($ShipRotationValueX1,2)) + ([math]::pow($PerviousShipRotationValueY1,2) - [math]::pow($ShipRotationValueY1,2)) + ([math]::pow($PerviousShipRotationValueZ1,2) - [math]::pow($ShipRotationValueZ1,2))) 
    $TriangleGroundB = $CurrentDeltaTotal
    $TriangleGroundC = [math]::Sqrt([math]::pow($TriangleGroundA,2) + [math]::pow($TriangleGroundB,2))
    $GroundVehicleAlpha = [math]::ASin($TriangleGroundA / $TriangleGroundC) * 180 / [System.Math]::PI 
    Write-Host "Course Diavation: $GroundVehicleAlpha (Ground)"

    # now subtract the vertical angle diavation, to get only the x angle
    # planet x y z



    #$ClosestQMX = $QMDistancesCurrent | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMStart.QuantumMarkerTo} | Sort-Object -Property DistanceX | Select-Object -First 1 
    #$ClosestQMY = $QMDistancesCurrent | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMStart.QuantumMarkerTo} | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMY.QuantumMarkerTo} | Sort-Object -Property DistanceY | Select-Object -First 1 
    #$ClosestQMZ = $QMDistancesCurrent | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMStart.QuantumMarkerTo} | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMY.QuantumMarkerTo} | Where-Object {$_.QuantumMarkerTo -NotContains $ClosestQMZ.QuantumMarkerTo}| Sort-Object -Property DistanceZ | Select-Object -First 1 
    #CLOSEST QM MARKER ON X AXIS
    $ClosestQMX = $QMDistancesCurrent | Sort-Object -Property DistanceX | Select-Object -First 1 
    #CLOSEST QM MARKER ON Y AXIS
    $ClosestQMY = $QMDistancesCurrent | Sort-Object -Property DistanceY | Select-Object -First 1 
    #CLOSEST QM MARKER ON Z AXIS
    $ClosestQMZ = $QMDistancesCurrent | Sort-Object -Property DistanceZ | Select-Object -First 1 

    #$QMXDistanceFinal = [math]::Sqrt([math]::pow($DestCoordDataX - $ClosestQMX.DistanceX,2) + [math]::pow($DestCoordDataY - $ClosestQMX.DistanceY,2) + [math]::pow($DestCoordDataZ - $ClosestQMX.DistanceZ,2))
    #$QMYDistanceFinal = [math]::Sqrt([math]::pow($ClosestQMY.DistanceX - $DestCoordDataX,2) + [math]::pow($ClosestQMY.DistanceY - $DestCoordDataY,2) + [math]::pow($ClosestQMY.DistanceZ - $DestCoordDataZ,2))
    #$QMZDistanceFinal = [math]::Sqrt([math]::pow($ClosestQMZ.DistanceX - $DestCoordDataX,2) + [math]::pow($ClosestQMZ.DistanceY - $DestCoordDataY,2) + [math]::pow($ClosestQMZ.DistanceZ - $DestCoordDataZ,2))

    #$InstructionDistanceQMX = [math]::Truncate($ClosestQMX.Distance/1000).ToString('N0')+"km" 
    #$InstructionDistanceQMY = [math]::Truncate($ClosestQMY.Distance/1000).ToString('N0')+"km" 
    #$InstructionDistanceQMZ = [math]::Truncate($ClosestQMZ.Distance/1000).ToString('N0')+"km" 

    if ($script:PlanetaryPoi) {
        $FinalInstructions = @()
        $StartingPoint  =  [ordered]@{Step = "1.";Type = "Start";Direction = "from"; QuantumMarker = $ClosestQMStart.QuantumMarkerTo;Distance = "-";TargetDistance = [math]::Truncate($ClosestQMStart.Distance/1000).ToString('N0')+"km"}
        $FirstStep =       [ordered]@{Step = "2.";Type = "Jump";Direction = "to";QuantumMarker = $OMGSStart;Distance = "-";TargetDistance = [math]::Truncate($OMGSDistanceToDestination/1000).ToString('N0')+"km"}
        $SecondStep =      [ordered]@{Step = "3.";Type = "Fly";Direction = "to";QuantumMarker = "$($SelectedDestination.Name)";Distance = [math]::Truncate($CurrentDistanceTotal/1000).ToString('N0')+"km";TargetDistance = "0 m"}
        $FinalInstructions += New-Object -Type PSObject -Property $StartingPoint
        $FinalInstructions += New-Object -Type PSObject -Property $FirstStep
        $FinalInstructions += New-Object -Type PSObject -Property $SecondStep
        Write-Host ($FinalInstructions | Format-Table -Property @{Name="Step"; Expression={$_.Step}; Align="Center"},Type,Direction,QuantumMarker,@{Name="Distance"; Expression={"   $($_.Distance)"}; Align="Right"},@{Name="TargetDistance"; Expression={$_.TargetDistance}; Align="Right"} | Out-String)
        $LiveResults.Text = ($FinalInstructions | Format-Table -Property @{Name="Step"; Expression={$_.Step}; Align="Center"},Type,Direction,QuantumMarker,@{Name="Distance"; Expression={$_.Distance}; Align="Right"},@{Name="TargetDistance"; Expression={$_.TargetDistance}; Align="Right"} | Out-String)
    }
       
    if ($ButtonDestinationJericho.Checked -eq $true) {
        $FinalInstructions = @()
        $StartingPoint  =  [ordered]@{Step = "1.";Type = "Start";Direction = "from"; QuantumMarker = "MIC-L1-STATION (Shallow Frontier)";JumpDistance = "-";TargetDistance = "0 m"}
        $FirstStep =       [ordered]@{Step = "2.";Type = "Jump";Direction = "to";QuantumMarker = "MIC-L1";JumpDistance = "5.961 km";TargetDistance = "6.782 km"}
        $SecondStep =      [ordered]@{Step = "3.";Type = "Jump";Direction = "to";QuantumMarker = "Hurston";JumpDistance = "689 km";TargetDistance = "34.269.072 km"}
        $ThirdStep =       [ordered]@{Step = "4.";Type = "Jump";Direction = "to";QuantumMarker = "ARC-L3";JumpDistance = "27.127 km";TargetDistance = "49.067.144 km"}
        $FourthStep =      [ordered]@{Step = "5.";Type = "Fly";Direction = "to";QuantumMarker = "$($SelectedDestination.Name)";JumpDistance = "-";TargetDistance = "-"}
        $FinalInstructions += New-Object -Type PSObject -Property $StartingPoint
        $FinalInstructions += New-Object -Type PSObject -Property $FirstStep
        $FinalInstructions += New-Object -Type PSObject -Property $SecondStep
        $FinalInstructions += New-Object -Type PSObject -Property $ThirdStep
        $FinalInstructions += New-Object -Type PSObject -Property $FourthStep
        Write-Host ($FinalInstructions | Format-Table -Property @{Name="Step"; Expression={$_.Step}; Align="Center"},Type,Direction,QuantumMarker,@{Name="JumpDistance"; Expression={$_.JumpDistance}; Align="Right"},@{Name="TargetDistance"; Expression={$_.TargetDistance}; Align="Right"} | Out-String)
        $LiveResults.Text = ($FinalInstructions | Format-Table -Property @{Name="Step"; Expression={$_.Step}; Align="Center"},Type,Direction,QuantumMarker,@{Name="JumpDistance"; Expression={$_.JumpDistance}; Align="Right"},@{Name="TargetDistance"; Expression={$_.TargetDistance}; Align="Right"} | Out-String)
    }
    #STORE PREVIOUS DISTANCES
    $PreviousXPosition     = $CurrentXPosition
    $PreviousYPosition     = $CurrentYPosition
    $PreviousZPosition     = $CurrentZPosition
    $PreviousDistanceTotal = $CurrentDistanceTotal
    $PreviousDistanceX     = $CurrentDistanceX
    $PreviousDistanceY     = $CurrentDistanceY
    $PreviousDistanceZ     = $CurrentDistanceZ
    $PreviousTime          = $CurrentTime
    $PreviousAngle         = $FinalAngle
    if($ShipRotationValueX1){$PerviousShipRotationValueX1 = $ShipRotationValueX1}
    if($ShipRotationValueY1){$PerviousShipRotationValueY1 = $ShipRotationValueY1}
    if($ShipRotationValuez1){$PerviousShipRotationValueZ1 = $ShipRotationValueZ1}
    $ScriptLoopCount ++

    }
    else{
        #Write-Host "no change"
    }
}

if ($script:ReloadForm){
    #$LiveResults.Text = $FinalInstructions
    $LiveResults.Text = ($FinalInstructions | Format-Table -Property @{Name="Step"; Expression={$_.Step}; Align="Center"},Type,Direction,QuantumMarker,@{Name="JumpDistance"; Expression={$_.JumpDistance}; Align="Right"},@{Name="TargetDistance"; Expression={$_.TargetDistance}; Align="Right"} -AutoSize | Out-String)
    $LiveResults.Text = Get-Process | Out-String
    $LiveResults
    Show-Frontend
    #$Form.Refresh()
    $script:ReloadForm = $false
}
#KEEP LAST RESULTS OPEN, AND EXIT SCRIPT IF USER PRESSES ENTER
Pause


#ToDo
# DeltaDistance 
# is fine positive
# adds 1km if negative

#ToDo #2
# Frontend
# Select System = Stanton, Pyro (Dropdown)
# Select Destination Type = Space, Orbital, Custom Space 
# Create different tabs for each type