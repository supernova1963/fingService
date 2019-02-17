##############################################
# $Id: 74_fingClient.pm 16965 2019-02-13 07:59:58Z gernot rau $
package main;

use strict;
use warnings;
use SetExtensions;

sub
fingClient_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "fingClient_Set";
  $hash->{DefFn}     = "fingClient_Define";
  $hash->{AttrList}  = "readingList setList useSetExtensions " .
                       "disable disabledForIntervals ".
                       $readingFnAttributes;
}

###################################
sub
fingClient_Set($@)
{
  my ($hash, @a) = @_;
  my $name = shift @a;

  return "no set value specified" if(int(@a) < 1);
  my $setList = AttrVal($name, "setList", " ");
  $setList =~ s/\n/ /g;

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
  };
  return if($doRet);


  my $v = join(" ", @a);
  Log3 $name, 4, "fingClient set $name $v";

  readingsSingleUpdate($hash,"state",$v,1);
  return undef;
}

sub
fingClient_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "Wrong syntax: use define <name> fingClient" if(int(@a) != 2);
  return undef;
}

1;

=pod
=item helper
=item summary    fingClient device
=item summary_DE fingClient Ger&auml;t
=begin html

<a name="fingClient"></a>
<h3>fingClient</h3>
<ul>

  Define a fingClient. A fingClient can take via <a href="#set">set</a> any values.
  Used for programming.
  <br><br>

  <a name="fingClientdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; fingClient</code>
    <br><br>

    Example:
    <ul>
      <code>define myvar fingClient</code><br>
      <code>set myvar 7</code><br>
    </ul>
  </ul>
  <br>

  <a name="fingClientset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt</code><br>
    Set any value.
  </ul>
  <br>

  <a name="fingClientget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="fingClientattr"></a>
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
      switches. Example: attr fingClientName setList on off </li>

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

<a name="fingClient"></a>
<h3>fingClient</h3>
<ul>

  Definiert eine Pseudovariable, der mit <a href="#set">set</a> jeder beliebige
  Wert zugewiesen werden kann.  Sinnvoll zum Programmieren.
  <br><br>

  <a name="fingClientdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; fingClient</code>
    <br><br>

    Beispiel:
    <ul>
      <code>define myvar fingClient</code><br>
      <code>set myvar 7</code><br>
    </ul>
  </ul>
  <br>

  <a name="fingClientset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt</code><br>
    Weist einen Wert zu.
  </ul>
  <br>

  <a name="fingClientget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="fingClientattr"></a>
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
      oder Schalter erzeugen.<br> Beispiel: attr fingClientName setList on off </li>

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
