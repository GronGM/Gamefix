# GameFix - graficheskaya obolochka. Zapuskaetsya ot administratora (GameFix.bat).
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$ENGINE = "$ROOT\gamefix.ps1"; $CFG = "$ROOT\config.txt"; $SVC = 'GameFix'

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameFix" Width="460" Height="590" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        FontFamily="Segoe UI" Foreground="#E6EDF3" TextOptions.TextFormattingMode="Ideal" UseLayoutRounding="True">
  <Window.Resources>
    <RadialGradientBrush x:Key="FaceOff" GradientOrigin="0.5,0.3" Center="0.5,0.4" RadiusX="0.7" RadiusY="0.7">
      <GradientStop Color="#2B3542" Offset="0"/><GradientStop Color="#171D26" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="FaceHover" GradientOrigin="0.5,0.3" Center="0.5,0.4" RadiusX="0.7" RadiusY="0.7">
      <GradientStop Color="#36424F" Offset="0"/><GradientStop Color="#1D242E" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="FaceOn" GradientOrigin="0.5,0.3" Center="0.5,0.4" RadiusX="0.7" RadiusY="0.7">
      <GradientStop Color="#3DDC84" Offset="0"/><GradientStop Color="#15803D" Offset="0.75"/><GradientStop Color="#0F5A2C" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="FaceBusy" GradientOrigin="0.5,0.3" Center="0.5,0.4" RadiusX="0.7" RadiusY="0.7">
      <GradientStop Color="#F2B544" Offset="0"/><GradientStop Color="#9A6508" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="HaloOn"><GradientStop Color="#803FB950" Offset="0.45"/><GradientStop Color="#003FB950" Offset="1"/></RadialGradientBrush>
    <RadialGradientBrush x:Key="HaloBusy"><GradientStop Color="#80E3A638" Offset="0.45"/><GradientStop Color="#00E3A638" Offset="1"/></RadialGradientBrush>

    <Style TargetType="Button" x:Key="Pill">
      <Setter Property="Background" Value="#1A222C"/>
      <Setter Property="Foreground" Value="#C9D1D9"/>
      <Setter Property="BorderBrush" Value="#2A3442"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Margin" Value="4,0"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="18" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#242E3A"/><Setter TargetName="B" Property="BorderBrush" Value="#3B4858"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button" x:Key="Ghost">
      <Setter Property="Foreground" Value="#6E7681"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="32"/>
      <Setter Property="Height" Value="28"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="Transparent" CornerRadius="6"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#242E3A"/><Setter Property="Foreground" Value="#E6EDF3"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border CornerRadius="16" BorderThickness="1" BorderBrush="#263040" Margin="12">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="0.3,1">
        <GradientStop Color="#151C26" Offset="0"/><GradientStop Color="#0B0F14" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Border.Effect><DropShadowEffect BlurRadius="24" ShadowDepth="6" Opacity="0.55" Color="#000000"/></Border.Effect>
    <Grid Margin="26,16,26,22">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" x:Name="TitleBar" Background="Transparent" Height="30">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
          <Button x:Name="BtnMin" Content="&#x2014;" Style="{StaticResource Ghost}"/>
          <Button x:Name="BtnClose" Content="&#x2715;" Style="{StaticResource Ghost}"/>
        </StackPanel>
      </Grid>

      <StackPanel Grid.Row="1" Margin="0,-4,0,0">
        <TextBlock FontSize="28" FontWeight="SemiBold" Foreground="#F0F6FC"><Run Text="Game"/><Run Text="Fix" Foreground="#3FB950"/></TextBlock>
        <TextBlock Text="обход блокировок для игр и Discord" FontSize="12.5" Foreground="#7D8590" Margin="1,0,0,0"/>
      </StackPanel>

      <Grid Grid.Row="2" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,6">
        <Button x:Name="BigBtn" Width="250" Height="250" Cursor="Hand" Background="Transparent" BorderThickness="0" Tag="off">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Grid>
                <Ellipse x:Name="Halo" Width="250" Height="250" Opacity="0" Fill="{StaticResource HaloOn}"/>
                <Ellipse x:Name="Ring" Width="206" Height="206" StrokeThickness="1.5" Stroke="#2A3442" Fill="Transparent"/>
                <Ellipse x:Name="Face" Width="186" Height="186" Fill="{StaticResource FaceOff}">
                  <Ellipse.Effect><DropShadowEffect BlurRadius="26" ShadowDepth="10" Opacity="0.6" Color="#000000"/></Ellipse.Effect>
                </Ellipse>
                <Ellipse Width="186" Height="186" StrokeThickness="1" Stroke="#33FFFFFF" Fill="Transparent"/>
                <StackPanel VerticalAlignment="Center">
                  <Path x:Name="Icon" Width="54" Height="54" Stretch="Uniform" Stroke="#8B949E" StrokeThickness="2.4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                        Data="M12,2 L12,12 M18.36,6.64 A9,9 0 1 1 5.64,6.64" Margin="0,0,0,10"/>
                  <TextBlock x:Name="Label" Text="ВЫКЛЮЧЕНО" FontSize="12.5" FontWeight="SemiBold" HorizontalAlignment="Center" Foreground="#8B949E"/>
                </StackPanel>
              </Grid>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="Face" Property="Fill" Value="{StaticResource FaceHover}"/>
                  <Setter TargetName="Icon" Property="Stroke" Value="#C9D1D9"/>
                </Trigger>
                <Trigger Property="Tag" Value="on">
                  <Setter TargetName="Face" Property="Fill" Value="{StaticResource FaceOn}"/>
                  <Setter TargetName="Ring" Property="Stroke" Value="#3FB950"/>
                  <Setter TargetName="Icon" Property="Stroke" Value="#FFFFFF"/>
                  <Setter TargetName="Label" Property="Foreground" Value="#FFFFFF"/>
                  <Setter TargetName="Label" Property="Text" Value="ВКЛЮЧЕНО"/>
                  <Setter TargetName="Halo" Property="Fill" Value="{StaticResource HaloOn}"/>
                  <Trigger.EnterActions>
                    <BeginStoryboard x:Name="Pulse">
                      <Storyboard RepeatBehavior="Forever" AutoReverse="True">
                        <DoubleAnimation Storyboard.TargetName="Halo" Storyboard.TargetProperty="Opacity" From="0.35" To="1" Duration="0:0:1.6"/>
                      </Storyboard>
                    </BeginStoryboard>
                  </Trigger.EnterActions>
                  <Trigger.ExitActions><StopStoryboard BeginStoryboardName="Pulse"/></Trigger.ExitActions>
                </Trigger>
                <Trigger Property="Tag" Value="busy">
                  <Setter TargetName="Face" Property="Fill" Value="{StaticResource FaceBusy}"/>
                  <Setter TargetName="Ring" Property="Stroke" Value="#E3A638"/>
                  <Setter TargetName="Icon" Property="Stroke" Value="#FFFFFF"/>
                  <Setter TargetName="Label" Property="Foreground" Value="#FFFFFF"/>
                  <Setter TargetName="Label" Property="Text" Value="ПОДОЖДИ"/>
                  <Setter TargetName="Halo" Property="Fill" Value="{StaticResource HaloBusy}"/>
                  <Setter TargetName="Halo" Property="Opacity" Value="0.7"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Face" Property="Opacity" Value="0.85"/></Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Button.Template>
        </Button>
      </Grid>

      <Border Grid.Row="3" CornerRadius="10" Background="#121820" BorderBrush="#1F2833" BorderThickness="1" Padding="14,10" Margin="0,4,0,14" MinHeight="54">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="Dot" Width="9" Height="9" Fill="#6E7681" Margin="0,0,10,0" VerticalAlignment="Center"/>
          <TextBlock x:Name="Status" Text="" FontSize="12.5" Foreground="#C9D1D9" TextWrapping="Wrap" MaxWidth="340" VerticalAlignment="Center"/>
        </StackPanel>
      </Border>

      <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center">
        <Button x:Name="BtnTest" Content="Диагностика" Style="{StaticResource Pill}"/>
        <Button x:Name="BtnRetest" Content="Подобрать" Style="{StaticResource Pill}"/>
        <Button x:Name="BtnHelp" Content="Помощь" Style="{StaticResource Pill}"/>
        <Button x:Name="BtnRemove" Content="Удалить" Style="{StaticResource Pill}"/>
      </StackPanel>

      <TextBlock x:Name="Foot" Grid.Row="5" Text="" FontSize="11" Foreground="#484F58" TextAlignment="Center" Margin="0,14,0,0"/>
    </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)
$BigBtn = $win.FindName('BigBtn'); $Status = $win.FindName('Status'); $Foot = $win.FindName('Foot'); $Dot = $win.FindName('Dot')
$BtnTest = $win.FindName('BtnTest'); $BtnRetest = $win.FindName('BtnRetest'); $BtnRemove = $win.FindName('BtnRemove'); $BtnHelp = $win.FindName('BtnHelp')
$BtnMin = $win.FindName('BtnMin'); $BtnClose = $win.FindName('BtnClose'); $TitleBar = $win.FindName('TitleBar')

$BtnClose.Add_Click({ $win.Close() })
$BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
$TitleBar.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
$win.Add_MouseLeftButtonDown({ param($s, $e) if ($e.OriginalSource -is [System.Windows.Controls.Border] -or $e.OriginalSource -is [System.Windows.Controls.Grid]) { try { $win.DragMove() } catch {} } })

function Get-State {
    $s = Get-Service $SVC -EA SilentlyContinue
    if (-not $s) { return 'absent' }
    if ($s.Status -eq 'Running' -and (Get-Process winws -EA SilentlyContinue)) { return 'on' }
    return 'off'
}
function Get-Strategy { if (Test-Path $CFG) { $l = Get-Content $CFG | Where-Object { $_ -match '^strategy=' }; if ($l) { return ($l -replace '^strategy=', '') } }; return '' }

function Refresh {
    $st = Get-State
    switch ($st) {
        'on'     { $BigBtn.Tag = 'on';  $Dot.Fill = '#3FB950'; $Status.Text = 'Защита включена. Игра и Discord идут в обход блокировок.'; $Foot.Text = 'стратегия ' + (Get-Strategy) + '  ·  автозапуск с Windows' }
        'off'    { $BigBtn.Tag = 'off'; $Dot.Fill = '#6E7681'; $Status.Text = 'Выключено. Нажми кнопку, чтобы включить.'; $Foot.Text = 'стратегия ' + (Get-Strategy) }
        'absent' { $BigBtn.Tag = 'off'; $Dot.Fill = '#6E7681'; $Status.Text = 'Ещё не настроено. Выключи VPN и нажми кнопку — подберу стратегию под твоего провайдера (1–2 минуты).'; $Foot.Text = '' }
    }
    $BtnRetest.IsEnabled = ($st -ne 'absent'); $BtnRemove.IsEnabled = ($st -ne 'absent')
}
function Busy($text) { $BigBtn.Tag = 'busy'; $Dot.Fill = '#E3A638'; $Status.Text = $text; $BigBtn.IsEnabled = $false; $BtnTest.IsEnabled = $false; $BtnRetest.IsEnabled = $false; $BtnRemove.IsEnabled = $false; $BtnHelp.IsEnabled = $false; [System.Windows.Forms.Application]::DoEvents() }
function Done { $BigBtn.IsEnabled = $true; $BtnTest.IsEnabled = $true; $BtnHelp.IsEnabled = $true; Refresh }
function Engine($action) {
    $p = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ENGINE`" -Action $action" -WindowStyle Hidden -PassThru
    while (-not $p.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 150 }
}
function LastLog($n) { if (Test-Path "$ROOT\gamefix-log.txt") { return ((Get-Content "$ROOT\gamefix-log.txt" -Tail $n) -replace '^\[[^\]]+\]\s*', '') -join "`n" }; return '' }
function VpnOn { return (Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and ($_.Name -match 'wwan|tun' -or $_.InterfaceDescription -match 'TUN|TAP|Wintun|WireGuard') }) }
# Posle ustanovki/podbora dvizhok pishet verdict.txt, tolko esli sluzhba ne povtorila rezultat podbora
function ShowInstallVerdict {
    if (-not (Test-Path "$ROOT\verdict.txt")) { return }
    $v = Get-Content "$ROOT\verdict.txt" -Raw
    $r = [System.Windows.MessageBox]::Show($v + "`n`nОткрыть отчёт GameFix-report.txt? Его можно переслать, если нужна помощь.", 'GameFix', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Start-Process notepad.exe "$ROOT\GameFix-report.txt" }
}

$BigBtn.Add_Click({
    $st = Get-State
    if ($st -eq 'on') {
        Busy 'Выключаю...'
        Stop-Service $SVC -Force -EA SilentlyContinue; Get-Process winws -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue; Start-Sleep 1
        Done
    } elseif ($st -eq 'off') {
        Busy 'Включаю...'
        Start-Service $SVC -EA SilentlyContinue; Start-Sleep 2
        $reinstalled = $false
        if ((Get-State) -ne 'on') { Remove-Item "$ROOT\verdict.txt" -EA SilentlyContinue; Engine 'install'; $reinstalled = $true }
        Done
        if ($reinstalled) { ShowInstallVerdict }
    } else {
        $vpn = VpnOn
        if ($vpn) { [System.Windows.MessageBox]::Show("Включён VPN ($($vpn.Name -join ', ')). Выключи его и нажми ещё раз — иначе подбор стратегии будет неверным.", 'GameFix', 'OK', 'Warning') | Out-Null; return }
        Busy 'Подбираю стратегию под провайдера... обычно 1–3 минуты'
        Remove-Item "$ROOT\verdict.txt" -EA SilentlyContinue
        Engine 'install'
        Done
        if ((Get-State) -ne 'on') { [System.Windows.MessageBox]::Show("Не получилось:`n`n" + (LastLog 6) + "`n`nПришли файл gamefix-log.txt тому, кто дал программу.", 'GameFix', 'OK', 'Error') | Out-Null }
        else { ShowInstallVerdict }
    }
})
$BtnTest.Add_Click({
    Busy 'Проверяю сайты, пинг и потери... 30–60 секунд'
    Remove-Item "$ROOT\verdict.txt" -EA SilentlyContinue
    Engine 'diag'
    Done
    $v = if (Test-Path "$ROOT\verdict.txt") { Get-Content "$ROOT\verdict.txt" -Raw } else { 'Диагностика не отработала. Пришли gamefix-log.txt.' }
    $r = [System.Windows.MessageBox]::Show($v + "`n`nОткрыть отчёт GameFix-report.txt? Его можно переслать, если нужна помощь.", 'GameFix — диагностика', 'YesNo', 'Information')
    if ($r -eq 'Yes') { Start-Process notepad.exe "$ROOT\GameFix-report.txt" }
})
$BtnHelp.Add_Click({
    $t = "Если не работает:`n`n" +
         "1. Выключи VPN и другие обходчики и ускорители (zapret, GoodbyeDPI, GearUP, ExitLag) — вместе с GameFix они мешают друг другу. Закрывай полностью, через значок в трее.`n" +
         "2. Нажми «Диагностика» — она скажет, в чём дело, и соберёт отчёт.`n" +
         "3. Перезапусти игру и Discord (Discord — выход через значок в трее).`n" +
         "4. Нажми «Подобрать» — переберёт стратегии заново (1–3 минуты, VPN выключен).`n" +
         "5. Лаги и потери в игре: «Диагностика» меряет пинг до роутера и до сервера игры и подскажет, где проблема — Wi-Fi, провайдер, загрузки или сам сервер.`n" +
         "6. Переместил папку — нажми «Подобрать», ярлык обновится.`n" +
         "7. Не помогло — отправь файл GameFix-report.txt (лежит в папке программы) тому, кто дал GameFix.`n`n" +
         "Антивирус ругается на WinDivert — это сетевой драйвер движка, ложное срабатывание: добавь папку в исключения."
    [System.Windows.MessageBox]::Show($t, 'GameFix — помощь', 'OK', 'Information') | Out-Null
})
$BtnRetest.Add_Click({
    $vpn = VpnOn
    if ($vpn) { [System.Windows.MessageBox]::Show("Сначала выключи VPN ($($vpn.Name -join ', ')).", 'GameFix', 'OK', 'Warning') | Out-Null; return }
    Busy 'Перебираю стратегии... 1–3 минуты'
    Remove-Item "$ROOT\verdict.txt" -EA SilentlyContinue
    Engine 'retest'
    Done
    ShowInstallVerdict
})
$BtnRemove.Add_Click({
    if ([System.Windows.MessageBox]::Show('Удалить GameFix из системы? Папку потом можно просто стереть.', 'GameFix', 'YesNo', 'Question') -ne 'Yes') { return }
    Busy 'Удаляю...'
    Engine 'uninstall'
    Done
})

Refresh
$win.ShowDialog() | Out-Null
