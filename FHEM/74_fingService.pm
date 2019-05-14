##############################################
# $Id: 74_fingService.pm supernova1963 $
package main;
use strict;
use warnings;
use SetExtensions;
use Blocking;
use JSON;
use Data::Dumper;


my $fingService_Version = "0.0.1";

sub
fingService_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "fingService_Set";
  $hash->{DefFn}     = "fingService_Define";
  $hash->{AttrList}  = "readingList setList useSetExtensions ".
                       "disable disabledForIntervals ".
                       "fingServiceServer ".
                       "fhemServer telnetPort globalPw ".
                       "fingService_Device fingService_Net fingService_RDNS:on,off fingService_Rounds ".
                       "autocreateDevices:0,1 ".
                       "fingDevice_Room fingDevice_Group fingDevice_ID:MAC,IP ".
                       $readingFnAttributes;
}

sub
fingService_Set($@)
{
  my ($hash1, @a) = @_;
  my ($hash, $name, $cmd, @args) = @_;
  my ($arg, @params) = @args;
  my $name1 = shift @a;
  my $list = '';

  return "no set value specified" if(int(@a) < 1);
  my $setList = AttrVal($name, "setList", " ");
  $setList =~ s/\n/ /g;

  my @adapterList = (ReadingsVal($name,"adapters",""));
  $setList = $setList
    ."fingInfo:noArg"
    ." fingDiscover:".join(",",@adapterList)
    ." fingDiscoverSession:"."read,reset"
    ." fingDiscoverJson:"."read,reset"
    ." fingDiscoverLog:"."start,stop,reset"
    ." fingService_start:".join(",",@adapterList);
    #." fingService_stop:".$hash->{helper}{SERVICE_PID}." ";

  if(AttrVal($name,"useSetExtensions",undef)) {
    my $a0 = $a[0]; $a0 =~ s/([.?*])/\\$1/g;
    if($setList !~ m/\b$a0\b/) {
      unshift @a, $name;
      return SetExtensions($hash, $setList, @a)
    }
    SetExtensionsCancel($hash);
  } else {
    return "Unknown argument ?, choose one of $setList" if($a[0] eq "?");
  }

  return undef
    if($attr{$name} &&  # Avoid checking it if only STATE is inactive
       ($attr{$name}{disable} || $attr{$name}{disabledForIntervals}) &&
       IsDisabled($name));

  my @rl = split(" ", AttrVal($name, "readingList", ""));
  my $doRet;
  eval {
    if(@rl && grep /\b$a[0]\b/, @rl) {
      my $v = shift @a;
      readingsSingleUpdate($hash, $v, join(" ",@a), 1);
      $doRet = 1;
    }
    elsif ($cmd eq 'fingInfo') {
      fingService_Info($name);
    }
    elsif ($cmd eq 'fingDiscover') {
      Log3 $hash, 3, $hash->{NAME}."fingService_Discover Auftrag wird erteilt!";

      my $fingparams->{netdiscover} = ReadingsVal($name,$arg."_network","");
      $fingparams->{net} = $arg;
      fingService_Discover($name,$fingparams);
    }
    elsif ($cmd eq 'fingDiscoverSession') {
        fingService_DiscoverSession($hash,$arg);
    }
    elsif ($cmd eq 'fingDiscoverJson') {
        fingService_DiscoverJson($hash,$arg);
    }
    elsif ($cmd eq 'fingDiscoverLog') {
        fingService_DiscoverLog($hash,$arg);
    }

    else {
      return "Unknown argument $cmd, choose one of $setList";
    }

  };
  return if($doRet);

  my $v = join(" ", @a);
  Log3 $name, 4, "fingService set $name $v";

  readingsSingleUpdate($hash,"state",$v,1);
  return undef;
}

sub
fingService_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $name = $hash->{NAME};
  return "Wrong syntax: use define <name> fingService" if(int(@a) != 2);
  my $rc = `fing -v`;
  my $regex = qr/(.).(.).(.)/mp;
  if ( $rc =~ /$regex/g ) {
    if (($1 < 5) | ($2 < 4) | ($3 < 0)){
      return "Fehler bei der Versionsprüfung (".$rc.")!\nDownload aktuelle Version von fing:\n https://www.fing.io/fingkit-sdk-downloads/";
    }
  }
  else {
      return "Fehler bei der Überprüfung von fing (".$rc.")!\nKann es sein, dass das fingCLI nicht installiert ist, oder der sudo Aufruf ohne Passwort nicht definiert ist?\nDownload fing:\n https://www.fing.io/fingkit-sdk-downloads/ \nEintrag sudoers: sudo visudo -f /etc/sudoers.d/fhem \n'fhem    ALL=(ALL) NOPASSWD: /usr/bin/nmap,/usr/bin/fing,/usr/sbin/service fingService start,/usr/sbin/service fingService stop,/usr/sbin/service fingService restart'";
  }
  # Übergabe der Define - Parameter in den Modul - hash
  $hash->{fingVersion} = $rc;
  $hash->{Version} = $fingService_Version;
  $rc = `ps -FC fing.bin |grep fing`;
  $regex = qr/(?<user>\S*)\s*(?<pid>\S*)\s{1,8}(?<ppid>\S*)\s{1,8}(?<c>\S*)\s{1,8}(?<sz>\S*)\s{1,8}(?<rss>\S*)\s{1,8}(?<psr>\S*)\s{1,8}(?<stime>\S*)\s{1,8}(?<tty>\S*)\s{1,8}(?<time>\S*)\s{1,8}(?<cmd>.*)\n/mp;
  if ( $rc =~ /$regex/g ) {
    $hash->{PROCESS}{PID} = $+{pid};
    $hash->{PROCESS}{USER} = $+{user};
    $hash->{PROCESS}{PPID} = $+{ppid};
    $hash->{PROCESS}{C} = $+{c};
    $hash->{PROCESS}{SZ} = $+{sz};
    $hash->{PROCESS}{RSS} = $+{rss};
    $hash->{PROCESS}{PSR} = $+{psr};
    $hash->{PROCESS}{STIME} = $+{stime};
    $hash->{PROCESS}{TTY} = $+{tty};
    $hash->{PROCESS}{TIME} = $+{time};
    $hash->{PROCESS}{CMD} = $+{cmd};
  }
  else {
    if (!defined(InternalVal($name,"NAME",undef))) {
      return "Fehler bei der Überprüfung von fing (".$rc.")!\nKann es sein, dass fingCLI nicht als Dienst läuft?";
    }
    else {
      readingsSingleUpdate($hash, "state", "fingService Dienst läuft nicht, bitte starten!", 1);
    }
  }
  fingService_Info($name) if (!defined(ReadingsVal($name,"adapters",undef)));
  $attr{$name}{autocreateDevices} = 0 if (!defined(AttrVal($name,"autocreateDevices",undef)));
  $attr{$name}{fhemServer} = "localhost" if (!defined(AttrVal($name,"fhemServer",undef)));
  $attr{$name}{fingDevice_Group} = "Geräte" if (!defined(AttrVal($name,"fingDevice_Group",undef)));
  $attr{$name}{fingDevice_ID} = "MAC" if (!defined(AttrVal($name,"fingDevice_ID",undef)));
  $attr{$name}{fingDevice_Room} = "99_Netzwerk" if (!defined(AttrVal($name,"fingDevice_Room",undef)));
  $attr{$name}{fingServiceServer} = "localhost" if (!defined(AttrVal($name,"fingServiceServer",undef)));
  $attr{$name}{fingService_Net} = "" if (!defined(AttrVal($name,"fingDevice_Group",undef)));
  $attr{$name}{fingService_RDNS} = "on" if (!defined(AttrVal($name,"fingService_RDNS",undef)));
  $attr{$name}{fingService_Rounds} = "1" if (!defined(AttrVal($name,"fingService_Rounds",undef)));
  $attr{$name}{room} = "99_Netzwerk" if (!defined(AttrVal($name,"room",undef)));
  $attr{$name}{group} = "Service" if (!defined(AttrVal($name,"group",undef)));
  $attr{$name}{sessionfile} = "/opt/fing/discovery.session" if (!defined(AttrVal($name,"sessionfile",undef)));
  $attr{$name}{jsonfile} = "/opt/fing/discovery.json" if (!defined(AttrVal($name,"jsonfile",undef)));
  $attr{$name}{logfile} = "/opt/fing/discovery.log" if (!defined(AttrVal($name,"logfile",undef)));
  if (!defined(ReadingsVal($name,"lastScan",undef))) {
    my $parameter->{rdns} = "on";
    $parameter->{rounds} = 1;
    #fingService_Discover($name,$parameter);
  }
  readingsSingleUpdate($hash, "state", "definiert", 1);


  return undef;
}

sub
fingService_Undef($$)
{
    my ($hash, $arg) = @_;
    my $param = "1";
    fingService_Clean($hash);
    return undef;
}

sub
fingService_Delete($$)
{
    my ($hash, $arg) = @_;
    my $param = "1";
    fingService_Clean($hash);
    return undef;
}

sub
fingService_Rename($$)
{
	my ( $new_name, $old_name ) = @_;

	my $old_index = "Module_fingService_".$old_name."_data";
	my $new_index = "Module_fingService_".$new_name."_data";

	my ($err, $data) = getKeyValue($old_index);
        #return undef unless(defined($old_pwd));

	setKeyValue($new_index, $data);
	setKeyValue($old_index, undef);
}

################################################################################
# Alle Timer und Hintergrundprozesse beenden
sub fingService_Clean($)
{
  my ($hash,$ClientDelete) = @_;
  # Internen Timer löschen
  RemoveInternalTimer($hash);
  # Wenn ein PID (Prozess-ID) im Helper des (Modul)-hash'es definiert ist: Prozess löschen
  BlockingKill($hash->{helper}{INFORUNNING_PID}) if(defined($hash->{helper}{INFORUNNING_PID}));
  BlockingKill($hash->{helper}{DISCOVERRUNNING_PID}) if(defined($hash->{helper}{DISCOVERRUNNING_PID}));
  BlockingKill($hash->{helper}{SERVICERUNNING_PID}) if(defined($hash->{helper}{SERVICERUNNING_PID}));
  BlockingKill($hash->{helper}{PINGRUNNING_PID}) if(defined($hash->{helper}{PINGRUNNING_PID}));
  BlockingKill($hash->{helper}{TRACEROUTRUNNING_PID}) if(defined($hash->{helper}{TRACEROUTRUNNING_PID}));
  Log3 $hash, 3, $hash->{NAME}.": Alle Timer und Hintergrundprozesse wurden beendet!";

  if ($ClientDelete eq "1") {
    fhem ( "delete TYPE=fingClient" );
  }

  return undef;
}
################################################################################
sub fingService_DiscoverSession($$)
{
  my ($hash,$parameter) = @_;
  my $name = $hash->{NAME};
  my $sessionfile = AttrVal($name,"sessionfile","/opt/fing/discovery.session");
  my $rc = "";
  if ($parameter eq "read") {
    open (FILEHANDLE,"<$sessionfile");
    my $session = do { local $/; <FILEHANDLE> };
    $hash->{helper}{session} = $session;
    Log3 $hash, 3, "$hash->{NAME}: sessionfile eingelesen!";
  }
  elsif ($parameter eq "reset") {
        $rc = `sudo /usr/bin/truncate -s 0 $sessionfile`;
    Log3 $hash, 3, "$hash->{NAME}: sessionfile gelöscht: $!";
  }
  else {
    Log3 $hash, 3, "$hash->{NAME}: sessionfile: $parameter: nothing todo!";
  }
}
################################################################################
sub fingService_DiscoverJson($$)
{
  my ($hash,$parameter) = @_;
  my $name = $hash->{NAME};
  my $jsonfile = AttrVal($name,"jsonfile","/opt/fing/discovery.json");
  my $rc = "";
  if ($parameter eq "read") {
    open (FILEHANDLE,"<$jsonfile");
    my $result = do { local $/; <FILEHANDLE> };
    my $regex = "";
    my $regex2 = "";
    my $rc = "";
    my $adapter = $hash->{helper}{fingDiscover}{net};
    my $net = $hash->{helper}{fingDiscover}{netdiscover};
    $result = urlDecode($result);
    my $json = new JSON;
    my $lastScanResult = $json->decode($result);
    $lastScanResult->{net} = $adapter;
    $lastScanResult->{lastScan} = TimeNow();
    my $perl_scalar = $json->decode($result);
    $hash->{helper}{fingDiscover}{result} = $json->pretty->encode($perl_scalar);
    Log3 $hash, 3, "$hash->{NAME}: jsonfile eingelesen!";
    fingService_Discover_expand($hash,$lastScanResult);
  }
  elsif ($parameter eq "reset") {
    $rc = `sudo /usr/bin/truncate -s 0 $jsonfile`;
    Log3 $hash, 3, "$hash->{NAME}: jsonfile geleert: $rc";
  }
  else {
    Log3 $hash, 3, "$hash->{NAME}: jsonfile: $parameter:  nothing todo!";
  }
}
################################################################################
sub fingService_DiscoverLog($$)
{
  my ($hash,$parameter) = @_;
  my $name = $hash->{NAME};
  my $rc = "";
  my $logfile = AttrVal($name,"logfile","/opt/fing/discovery.log");
  if ($parameter eq "read") {
    open (FILEHANDLE,"<$logfile");
    my $log = do { local $/; <FILEHANDLE> };
    $hash->{helper}{log} = $log;
    Log3 $hash, 3, "$hash->{NAME}: logfile eingelesen!";
  }
  elsif ($parameter eq "reset") {
    $rc = `sudo /usr/bin/truncate -s 0 $logfile`;
    Log3 $hash, 3, "$hash->{NAME}: logfile geleert: $rc";
  }
  else {
    Log3 $hash, 3, "$hash->{NAME}: logfile: $parameter: nothing todo!";
  }
}



################################################################################
# fingService_Discover - Netzwerk scannen

# fingService_Discover Aufruf
sub fingService_Discover($$)
{
    my ($name,$fing_Parameter) = @_;
    my $hash = $defs{$name};
    return undef if (IsDisabled($hash->{NAME}));
    # fing Parameter -n mit Attribut fingService_Net abgleichen
    if ($fing_Parameter->{netdiscover} || $fing_Parameter->{netdiscover} ne "") {
      $attr{$name}{"fingService_Net"} = $fing_Parameter->{netdiscover};
    }
    elsif (AttrVal($name,"fingService_Net",undef) ne "") {
      $fing_Parameter->{netdiscover} = $attr{$name}{"fingService_Net"};
    }
    else {
      $fing_Parameter->{netdiscover} = "";
    }
    # fing Parameter -d mit Attribut fingService_DNS abgleichen
    if ($fing_Parameter->{rdns} || $fing_Parameter->{rdns} ne "") {
      $attr{$name}{"fingService_RDNS"} = $fing_Parameter->{rdns};
    }
    else {
      $fing_Parameter->{rdns} = $attr{$name}{"fingService_RDNS"};
    }
    # fing Parameter -r mit Attribut fingService_Rounds (Anzahl Discover - Runden) abgleichen
    if ($fing_Parameter->{rounds} || $fing_Parameter->{rounds} ne "") {
      $attr{$name}{"fingService_Rounds"} = $fing_Parameter->{rounds};
    }
    elsif (AttrVal($name,"fingService_Rounds",undef) ne "") {
      $fing_Parameter->{rounds} = $attr{$name}{"fingService_Rounds"};
    }
    else {
      $fing_Parameter->{rounds} = 1;
    }
    while ( my ($key, $value) = each %$fing_Parameter) {
      $hash->{helper}{fingDiscover}{$key} = $value;
    }

    readingsSingleUpdate($hash, "state", "fingService_Discover läuft für: ".$fing_Parameter->{host}, 1);
    my $arg = $name;
    my $blockingFn = "fingService_Discover_run";
    my $finishFn = "fingService_Discover_finished";
    my $abortFn = "fingService_Discover_abort";
    my $timeout = 60 * $fing_Parameter->{rounds} + 20;
    if (!(exists($hash->{helper}{DISCOVERRUNNING_PID}))) {
        $hash->{helper}{DISCOVERRUNNING_PID} = BlockingCall($blockingFn,$arg,$finishFn,$timeout,$abortFn,$hash);
        Log3 $hash, 3, "$hash->{NAME}: fingService_Discover Auftrag wurde erteilt!";
    }
    else {
        Log3 $hash, 3, "$hash->{NAME}: Blocking Call fingService_Discover läuft, es wurde kein neuer gestartet!";
    }
}
# fingService_Discover_run() Blocking Sub-Routine wird ausgeführt
sub fingService_Discover_run($)
{
    my ($name) = @_;
    my $result = "";
    my $hash = $defs{$name};

    my $fingBefehl = "sudo fing";
    if ($hash->{helper}{fingDiscover}{netdiscover} || $hash->{helper}{fingDiscover}{netdiscover} ne "") {
        $fingBefehl .= " -n ".$hash->{helper}{fingDiscover}{netdiscover};
    }
    if ($hash->{helper}{fingDiscover}{rdns} || $hash->{helper}{fingDiscover}{rdns} ne "") {
      $fingBefehl .= " -d ".$hash->{helper}{fingDiscover}{rdns};
    }
    if ($hash->{helper}{fingDiscover}{rounds} || $hash->{helper}{fingDiscover}{rounds} ne "") {
      $fingBefehl .= " -r ".$hash->{helper}{fingDiscover}{rounds};
    }
    $fingBefehl .= " -o  table,json,console --silent";
    Log3 $hash, 3, $hash->{NAME}.": Blocking Call fingService_Discover startet: $fingBefehl";
    $result = `$fingBefehl`;
    $result = urlEncode($result);
    return $name."|".$result;
}
# fingService_Discover_finished() Blocking Sub-Routine wurde abgeschlossen
sub fingService_Discover_finished($)
{
    my ($string) = @_;
    my ($name, $result) = split("\\|", $string);
    my $hash = $defs{$name};
    my $regex = "";
    my $regex2 = "";
    my $adapter = $hash->{helper}{fingDiscover}{net};
    my $net = $hash->{helper}{fingDiscover}{netdiscover};

    my $adapters = "";
    my $ip = "";
    my $ipdef = 0;

    $result = urlDecode($result);
    my @roundresults = split(/\n/,$result);
    my $json = new JSON;
    my $i = 0;
    my $runde = "round_".$i;
    my $lastScanResult = $json->decode($roundresults[$#roundresults]);
    $lastScanResult->{net} = $adapter;
    $lastScanResult->{lastScan} = TimeNow();
    foreach my $roundresult (reverse(@roundresults)) {
      my $perl_scalar = $json->decode($roundresult);
      $hash->{helper}{fingDiscover}{result}{$runde} = $json->pretty->encode($perl_scalar);
      $i = $i + 1;
      $runde = "round_".$i;
    }
    $hash->{helper}{fingDiscover}{lastScan} = TimeNow();
    delete($hash->{helper}{DISCOVERRUNNING_PID});
    readingsSingleUpdate($hash, "state", "fingService_Discover $i Runden für $net beendet", 1);
    Log3 $name, 3, "$name: fingService_Discover $i Runden für $net beendet";

    fingService_Discover_expand($hash,$lastScanResult);
}
# fingService_Discover_abort Blocking Sub-Routine wurde abgebrochen
sub fingService_Discover_abort($)
{
    my ($hash) = @_;
    delete($hash->{helper}{DISCOVERRUNNING_PID});
    readingsSingleUpdate($hash, "state", "fingService_Discover wurde abgebrochen", 1);
    Log3 $hash->{NAME}, 3, "fingService_Discover für ".$hash->{NAME}." wurde abgebrochen";

}
################################################################################
sub fingService_Discover_expand($$)
{
  my ($hash,$lastScanResult) = @_;
  my $name = $hash->{NAME};
  my $hashDevice = $hash;
  my $hashDeviceName = "";
  my $i = 0;
  my $e1 = "";
  my $e2 = "";
  my $e3 = "";
  my $e4 = "";
  my $temp = "";
  my $regex = "";
  my $subst = "";

  # Die letzten "State - readings" löschen
  fhem("deletereading $name IP_.*_state");
  fhem("deletereading $name MAC_.*_state");
  # Alle fingDevices des Netzes auf "down" setzen
  fhem("set TYPE=fingDevice down");

  # Grunddaten der letzten Runde im letzten Discover - Laufes am fingService device als readings speichern
  readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash, "lastScan", TimeNow());
    readingsBulkUpdateIfChanged($hash, $lastScanResult->{net}."_NetworkFamily", $lastScanResult->{NetworkFamily});
    readingsBulkUpdateIfChanged($hash, $lastScanResult->{net}."_lastScan", $lastScanResult->{lastScan});
    readingsBulkUpdateIfChanged($hash, $lastScanResult->{net}."_NetworkAddress", $lastScanResult->{NetworkAddress});
    readingsBulkUpdateIfChanged($hash, $lastScanResult->{net}."_NetworkBearer", $lastScanResult->{NetworkBearer});
  readingsEndUpdate($hash,0);

  # Detaildaten der letzten Runde des letzten Discovery - Laufes ablegen
  my $praefix = "";
  foreach my $client (@{ $lastScanResult->{Hosts} }) {
    # IP hat jeder Host des Discover - Laufes
    $temp = $lastScanResult->{Hosts}->[$i]->{Address};
    # IP aufbereiten -> Punkte entfernen und auf 3 Stellen mit 0 auffüllen
    my $regex = qr/(?<e1>.*)\.(?<e2>.*)\.(?<e3>.*)\.(?<e4>.*)/mp;
    if ( $temp =~ /$regex/g ) {
      $e1 = sprintf("%03d", $+{e1});
      $e2 = sprintf("%03d", $+{e2});
      $e3 = sprintf("%03d", $+{e3});
      $e4 = sprintf("%03d", $+{e4});
      $temp = sprintf("%03d", $e1)."".sprintf("%03d", $e2)."".sprintf("%03d", $e3)."".sprintf("%03d", $e4);
    }
    else {
      Log3 $hash, 3, "IP Address konnte nicht aufbereitet werden: ".$temp;
    }
    ###
    # Vorgabe für die Namensgebung (IP|MAC) ermitteln bzw. setzen
    if (AttrVal($name,"fingDevice_ID","IP") eq "IP" || $lastScanResult->{Hosts}->[$i]->{HardwareAddress} eq "" || !defined($lastScanResult->{Hosts}->[$i]->{HardwareAddress})) {
      $temp = "IP_".$temp;
      $attr{$name}{fingDevice_ID} = "IP";
      Log3 $hash, 5, "Aufbereitete IP Address: ".$temp;
    }
    else {
      $temp = $lastScanResult->{Hosts}->[$i]->{HardwareAddress};
      $regex = qr/:/mp;
      $subst = '';
      $temp = $temp =~ s/$regex/$subst/rg;
      $temp = "MAC_".$temp;
      Log3 $hash, 5, "Aufbereitete MAC Address: ".$temp;
    }
    Log3 $hash, 5, "zuprüfende Attribut autocreateDevices: ".AttrVal($name,"autocreateDevices",0);

    # Vorgabe für die Erstellung von fingClient - Devices (autocreateDevices = 1) prüfen, ggf. anlegen
    if (AttrVal($name,"autocreateDevices",0) == 1) {
      $praefix = $temp;
      fhem("defmod ".$praefix." fingClient");
      # Hash und Name des neuen fingClient Devices übernehmen und entsprechende Voreinstellungen vornehmen
      $hashDevice = $defs{$praefix};
      $hashDeviceName = $hashDevice->{NAME};
      fhem("set ".$hashDeviceName." ".$lastScanResult->{Hosts}->[$i]->{State});
      $attr{$hashDeviceName}{room} = AttrVal($hash,"fingDevice_Room","99_Netzwerk");
      $attr{$hashDeviceName}{group} = AttrVal($name,"fingDevice_Group","Geräte");
      # alias Attribut auf Name setzen, wenn in der Benutzervorgabe in fing Voreinstellungen hosts.properties erfasst wurde, wird er als Name im Scanergebnis abgelegt
      if ($lastScanResult->{Hosts}->[$i]->{Name} ne "") {
        $attr{$hashDeviceName}{alias} = $lastScanResult->{Hosts}->[$i]->{Name};
        Log3 $hash, 5, "$hashDeviceName: alias wird auf: '".$lastScanResult->{Hosts}->[$i]->{Name}."' gesetzt!";
      }
      # alias Attribut setzen, wenn in fing Voreinstellungen rdns = on erfasst wurde, wird dns Name als Hostname im Scanergebnis abgelegt
      elsif ($lastScanResult->{Hosts}->[$i]->{Hostname} ne "") {
        $attr{$hashDeviceName}{alias} = $lastScanResult->{Hosts}->[$i]->{Hostname};
        Log3 $hash, 5, "$hashDeviceName: alias wird auf: '".$lastScanResult->{Hosts}->[$i]->{Hostname}."' gesetzt!";
      }
      # wenn weder Name noch Hostname einen Wert enthät, alias nicht setzen
      else {
        Log3 $hash, 5, "$hashDeviceName: Name oder Hostname verfügbar, alias wird nicht belegt";
      }
      $attr{$hashDeviceName}{sortby} = $e4;
      $praefix = "";
    Log3 $hash, 5, "Neues fing_Device angelegt: ".$hashDeviceName;
    }
    else {
      # Es sollen keine fingClient devices angelegt werden, und die Ergebnisse als Readings des fingService devices abgelegt werden
      $praefix = $temp."_";
      $hashDevice = $hash;
      Log3 $hash, 5, "Für das Device weden Readings mit dem Präfix: ".$praefix." angelegt.";
    }

    # Readings des neuen fingClient bzw. des fingService devices setzen wenn geändert
    readingsBeginUpdate($hashDevice);
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Interface", $lastScanResult->{net});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Network", $lastScanResult->{netdiscover});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Vendor", $lastScanResult->{Hosts}->[$i]->{Vendor});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."LastChangeTime", $lastScanResult->{Hosts}->[$i]->{LastChangeTime});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Hostname", $lastScanResult->{Hosts}->[$i]->{Hostname});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."HardwareAddress", $lastScanResult->{Hosts}->[$i]->{HardwareAddress});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."state", $lastScanResult->{Hosts}->[$i]->{State});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Address", $lastScanResult->{Hosts}->[$i]->{Address});
    readingsBulkUpdateIfChanged($hashDevice, $praefix."Name", $lastScanResult->{Hosts}->[$i]->{Name});
    $i = $i + 1;
  }
  readingsEndUpdate($hashDevice,0);

  # Abschlussstatus im Log und im state des fingService devices ablegen
  if (AttrVal($name,"autocreateDevices",0) == 1) {
    readingsSingleUpdate($hash, "state", "$i Geräte als FHEM devices angelegt/geändert", 1);
    Log3 $hash, 3, "$i Geräte als FHEM devices angelegt/geändert";
  }
  else {
    readingsSingleUpdate($hash, "state", "Discover-Readings an $name für $i Geräte angelegt/geändert‚", 1);
    Log3 $hash, 3, "Discover-Readings an $name für $i Geräte angelegt/geändert";
  }
}
################################################################################

################################################################################
# fingInfo - Basisdaten holen

# fingService_Info Aufruf
sub fingService_Info($)
{
    my ($name) = @_;
    my $hash = $defs{$name};
    return undef if (IsDisabled($hash->{NAME}));
    readingsSingleUpdate($hash, "state", "running fing -i", 1);
    my $arg = $name;
    my $blockingFn = "fingService_Info_run";
    my $finishFn = "fingService_Info_finished";
    my $abortFn = "fingService_Info_abort";
    if (!(exists($hash->{helper}{INFORUNNING_PID}))) {
        $hash->{helper}{INFORUNNING_PID} = BlockingCall($blockingFn,$arg,$finishFn,20,$abortFn,$hash);
        Log3 $hash, 3, "$hash->{NAME}: fingService_Info Auftrag wurde erteilt!";
    }
    else {
        Log3 $hash, 3, "$hash->{NAME}: Blocking Call fingService_Info läuft, es wurde kein neuer gestartet!";
    }
}

# fingService_Info_run() Blocking Sub-Routine wird ausgeführt
sub fingService_Info_run($)
{
    my ($name) = @_;
    my $result = "";
    my $fingBefehl = "fing -i &";
    $result = `$fingBefehl`;
    $result = urlEncode($result);
    return $name."|".$result;
}

# fingService_Info_finished() Blocking Sub-Routine wurde abgeschlossen
sub fingService_Info_finished($)
{
    my ($string) = @_;
    my ($name, $result) = split("\\|", $string);
    my $hash = $defs{$name};
    my $regex = "";
    my $regex2 = "";
    my $adapter = "";
    my $adapters = "";
    my $networks = "";
    my $ip = "";
    my $ipdef = 0;

    $result = urlDecode($result);
    $hash->{helper}{fingInfo} = $result;
    if ($result) {
      $regex = qr/\t(?<adapters>.*):\n\t\tType:\s*(?<type>.*)\n\t\tHardware address:\s(?<mac>.*)\n\t\tIP address:\s*(?<ipdef>.*)\n/mp;
      while ($result =~ /$regex/g) {
        $adapter = $+{adapters};
        if ($adapters ne "") {
          $adapters .= ",".$adapter;
        }
        else {
          $adapters = $adapter;
        }
        readingsSingleUpdate($hash, "adapters", $adapters, 1);
        readingsSingleUpdate($hash, $adapter."_adapter", $+{adapters}, 1);
        readingsSingleUpdate($hash, $adapter."_type", $+{type}, 1);
        readingsSingleUpdate($hash, $adapter."_mac", $+{mac}, 1);
        $ipdef = $+{ipdef};
        $regex2 = qr/(?<ip>.*)\/(?<seg>.*)\s/mp;
        #readingsSingleUpdate($hash, $adapter."_ipdef", $ipdef, 1);
        if ($ipdef =~ /$regex2/g) {
          if ($networks ne "") {
            $networks .= ",".$+{ip}."/".$+{seg};
          }
          else {
            $networks = $+{ip}."/".$+{seg};
          }
          readingsSingleUpdate($hash, $adapter."_ip", $+{ip}, 1);
          readingsSingleUpdate($hash, $adapter."_seg", $+{seg}, 1);
          readingsSingleUpdate($hash, $adapter."_network", $+{ip}."/".$+{seg}, 1);
          readingsSingleUpdate($hash, "networks", $networks, 1);
        }
      }
       $regex = qr/Default gateway:\n(?<gateway>.*)\n\s*DNS Servers:\n(?<dns>.*)\n/mp;
       if ( $result =~ /$regex/g ) {
         readingsSingleUpdate($hash, "default_gateway", $+{gateway}, 1);
         readingsSingleUpdate($hash, "dns_servers", $+{dns}, 1);
       }
    }
    #delFromDevAttrList($name,"fingService_Net");
    #addToDevAttrList($name,"fingService_Net:".$networks);
    Log3 $name, 3, "$name: fingInfo beendet!";
    # zum Abschluss wird die "RUNNING_PID des helpers des devices gelöscht
    delete($hash->{helper}{INFORUNNING_PID});
    readingsSingleUpdate($hash, "state", "fingInfo beendet", 1);
}

# fingService_Info_abort Blocking Sub-Routine wurde abgebrochen
sub fingService_fingInfo_abort($)
{
    my ($hash) = @_;
    delete($hash->{helper}{PINGRUNNING_PID});
    Log3 $hash->{NAME}, 3, "fingService_Info für ".$hash->{NAME}." wurde abgebrochen";

}
################################################################################
# fingService
# Kennzeichen für das Ende des fhem - Moduls
1;

=pod
=item helper
=item summary    fingService device
=item summary_DE fingService Ger&auml;t
=begin html

<a name="fingService"></a>
<h3>fingService</h3>
<ul>

  --- Not yet available ---
  Define a fingService. A fingService can take via <a href="#set">set</a> any values.
  Used for programming.
  <br><br>

  <a name="fingServicedefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; fingService</code>
    <br><br>

    Example:
    <ul>
      <code>define myvar fingService</code><br>
      <code>set myvar 7</code><br>
    </ul>
  </ul>
  <br>

  <a name="fingServiceset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt</code><br>
    Set any value.
  </ul>
  <br>

  <a name="fingServiceget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="fingServiceattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#disabledForIntervals">disabledForIntervals</a></li>
    <li><a name="readingList">readingList</a><br>
      Space separated list of readings, which will be set, if the first
      argument of the set command matches one of them.</li>

    <li><a name="setList">setList</a><br>
      Space separated list of commands, which will be returned upon "set name
      ?", so the FHEMWEB frontend can construct a dropdown and offer on/off
      switches. Example: attr fingServiceName setList on off </li>

    <li><a name="useSetExtensions">useSetExtensions</a><br>
      If set, and setList contains on and off, then the
      <a href="#setExtensions">set extensions</a> are supported.
      In this case no arbitrary set commands are accepted, only the setList and
      the set exensions commands.</li>

    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>

</ul>

=end html

=begin html_DE

<a name="fingService"></a>
<h3>fingService</h3>
<ul>

  --- noch nicht verfügbar ---
  Definiert eine Pseudovariable, der mit <a href="#set">set</a> jeder beliebige
  Wert zugewiesen werden kann.  Sinnvoll zum Programmieren.
  <br><br>

  <a name="fingServicedefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; fingService</code>
    <br><br>

    Beispiel:
    <ul>
      <code>define myvar fingService</code><br>
      <code>set myvar 7</code><br>
    </ul>
  </ul>
  <br>

  <a name="fingServiceset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt</code><br>
    Weist einen Wert zu.
  </ul>
  <br>

  <a name="fingServiceget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="fingServiceattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#disabledForIntervals">disabledForIntervals</a></li>
    <li><a name="readingList">readingList</a><br>
      Leerzeichen getrennte Liste mit Readings, die mit "set" gesetzt werden
      k&ouml;nnen.</li>

    <li><a name="setList">setList</a><br>
      Liste mit Werten durch Leerzeichen getrennt. Diese Liste wird mit "set
      name ?" ausgegeben.  Damit kann das FHEMWEB-Frontend Auswahl-Men&uuml;s
      oder Schalter erzeugen.<br> Beispiel: attr fingServiceName setList on off </li>

    <li><a name="useSetExtensions">useSetExtensions</a><br>
      Falls gesetzt, und setList enth&auml;lt on und off, dann die <a
      href="#setExtensions">set extensions</a> Befehle sind auch aktiv.  In
      diesem Fall werden nur die Befehle aus setList und die set exensions
      akzeptiert.</li>

    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>

</ul>

=end html_DE

=cut
