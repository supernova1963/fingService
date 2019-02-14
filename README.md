# fhem modul: fingService

1. Netzwerk scannen (yant)
2. ...

## Voraussetzungen

1. linux (debian based, getestet unter ubuntu server 18.04 lts)
2. fhem (Version >= 5.9) -> http://fhem.de/fhem-5.9.deb
3. fingCLI (Version >= 5.3.3) -> https://www.fing.com/images/uploads/general/CLI_Linux_Debian.zip
4. sudo ohne Paswort für fing (sudoersd)
5. perl module JSON

## Installation

1. benötigte Pakete holen
```
mkdir ~/fingService
cd ~/fingService
wget https://www.fing.com/images/uploads/general/CLI_Linux_Debian.zip
```
2. ggf. z.B. wenn fhem als docker container läuft, wird libicu55 benötigt:
```
wget http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu55_55.1-7ubuntu0.4_amd64.deb
sudo apt install ./libicu55_55.1-7ubuntu0.4_amd64.deb
```
3. fingCLI Installation:
```
unzip CLI_Debian.zip
sudo apt install ./fing-5.3.3-amd64.deb
```
4. ggf. perl Modul JSON installieren: `sudo apt install libjson-perl`
5. user fhem erlauben nachstehende sudo Befehle ohne Passworteingabe auszuführen
```
sudo visudo -f /etc/sudoers.d/fing
```
und nachstehende Zeile im Editor einfügen:
```
fhem    ALL=(ALL) NOPASSWD: /usr/bin/fing, /usr/sbin/service fingService start,/usr/sbin/service fingService stop,/usr/sbin/service fingService restart
```
speichern: [Strg]+x,[Eingabe],[Eingabe]

6. Neustart:`sudo reboot`

## Definition

`define netz fingService`
