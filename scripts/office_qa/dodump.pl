use utf8; use strict; no strict 'vars'; use FindBin qw($Bin); use JSON::PP; use POSIX;
our $DO; BEGIN { $DO = $ENV{DO_ROOT} or die "set DO_ROOT to the divinum-officium checkout"; $FindBin::Bin = "$DO/web/cgi-bin/horas"; }
use lib "$DO/web/cgi-bin";
our $datafolder = "$DO/web/www/horas";
our ($version, $dayofweek, $day, $month, $year, $hora, $missa, $lang1, $lang2, $error, $debug, $votive, @dayname, $winner, %winner, $rank, $rule, $communetype, $commune, $duplex, $missanumber, $dioecesis) ;
require "$DO/web/cgi-bin/DivinumOfficium/SetupString.pl";
$version = shift @ARGV; my $mode = shift @ARGV; # 'rules' or 'psalt'
our $L2 = $ENV{DO_LANG2} // 'English';  # the second column: English, or another DO language (Espanol)
$hora='Laudes'; $dayofweek=$ENV{DO_DOW} // 1; $day=1; $month=1; $year=2026; $missa=0; $votive='Hodie'; $lang1='Latin'; $lang2='English';
binmode(STDOUT, ':encoding(utf-8)');
my %out;
if ($mode eq 'rules') {
  for my $dir ('Sancti','Tempora','Commune') {
    opendir(my $dh, "$datafolder/Latin/$dir"); my @files = grep { /\.txt$/ } readdir($dh); closedir($dh);
    for my $f (sort @files) {
      my $s = setupstring('Latin', "$dir/$f") or next;
      $out{"$dir/$f"} = { Rank => $s->{Rank}, Rule => $s->{Rule}, Officium => $s->{Officium}, keys => [sort keys %$s] };
    }
  }
} elsif ($mode eq 'ordo') {
  # DO's own precedence for every date: the winning office file, its rank,
  # commune, the Lauds scheme, and the Vespers concurrence.
  $Bin = "$DO/web/cgi-bin/horas";
  require "$DO/web/cgi-bin/horas/horascommon.pl";
  require "$DO/web/cgi-bin/DivinumOfficium/dialogcommon.pl";
  require "$DO/web/cgi-bin/horas/specials.pl";
  require "$DO/web/cgi-bin/horas/specmatins.pl";
  require "$DO/web/cgi-bin/horas/horas.pl";
  require "$DO/web/cgi-bin/DivinumOfficium/setup.pl";
  require "$DO/web/cgi-bin/DivinumOfficium/Main.pm";
  use DivinumOfficium::Directorium qw(get_from_directorium transfered hymnshift hymnmerge hymnshiftmerge);
  use DivinumOfficium::Date qw(getweek geteaster nextday prevnext leapyear get_sday day_of_week monthday);
  our $dioecesis = 'Generale'; our $testmode = ''; our $column = 1; our $buildscript = ''; our $expand = 'all';
  my ($start, $end) = @ARGV;
  my ($y, $m, $d) = split('-', $start); my ($ey, $em, $ed) = split('-', $end);
  my $t = POSIX::mktime(0, 0, 12, $d, $m - 1, $y - 1900); my $te = POSIX::mktime(0, 0, 12, $ed, $em - 1, $ey - 1900);
  while ($t <= $te) {
    my @lt = localtime($t); my $ds = sprintf("%d-%d-%d", $lt[4] + 1, $lt[3], $lt[5] + 1900); my $iso = sprintf("%04d-%02d-%02d", $lt[5] + 1900, $lt[4] + 1, $lt[3]);
    my %ent;
    for my $h ('Laudes', 'Vespera') {
      $hora = $h; $vespera = ($h eq 'Vespera') ? 3 : 2; $cwinner = ''; $cvespera = 0; $commemoratio = ''; $antecapitulum = ''; $octvespera = 0; $transfervigil = '';
      eval { precedence($ds); };
      if ($@) { $ent{lc($h)} = { error => "$@" }; next; }
      my $mdflag = ($winner =~ /tempora/i && $vespera == 1) ? 1 : 0;
      my $md = ''; if ($winner) { officestring('Latin', $winner, $mdflag); $md = $main::monthday || ''; }
      $ent{lc($h)} = { winner => $winner, rank => $rank + 0, monthday => $md, dayname0 => $dayname[0], dayname1 => $dayname[1], dayname2 => $dayname[2],
        commune => $commune, communetype => $communetype, laudes => $laudes, vespera => $vespera, commemoratio => $commemoratio,
        commemoentries => [@commemoentries], comrank => $comrank + 0, duplex => $duplex, rule => $rule, tomorrowname0 => $tomorrowname[0],
        cwinner => $cwinner, cvespera => $cvespera + 0, ccommemoentries => [@ccommemoentries], antecapitulum => $antecapitulum, transfervigil => $transfervigil,
        octvespera => ($octvespera || 0) + 0, trank0 => ($trank[0] || ''),
        hy => (hymnmerge($version, $lt[3], $lt[4] + 1, $lt[5] + 1900, $dioecesis) ? 1 : hymnshift($version, $lt[3], $lt[4] + 1, $lt[5] + 1900, $dioecesis) ? 2 : hymnshiftmerge($version, $lt[3], $lt[4] + 1, $lt[5] + 1900, $dioecesis) ? 3 : 0) };
    }
    # DO's scripture-cycle key for the date and for the following day (officestring's monthday()).
    { my ($yy,$mm,$dd) = ($lt[5] + 1900, $lt[4] + 1, $lt[3]); my $modern = ($version =~ /196/) + 0;
      $ent{md0} = monthday($dd, $mm, $yy, $modern, 0) || ''; $ent{md1} = monthday($dd, $mm, $yy, $modern, 1) || ''; }
    $out{$iso} = \%ent;
    $t += 86400;
  }
} elsif ($mode eq 'commune') {
  opendir(my $dh, "$datafolder/Latin/Commune"); my @files = grep { /\.txt$/ } readdir($dh); closedir($dh);
  for my $f (sort @files) {
    # The Paschaltide communes (C1p, C3ap, C10Pasc ...) resolve their
    # "(tempore paschali)" sections in Paschaltide.
    @dayname = (($f =~ /p\.txt$|Pasc/i) ? 'Pasc1' : '', '', ''); %main::setupstring_caches_by_version = ();
    my $s = setupstring('Latin', "Commune/$f") or next;
    my $e = setupstring($L2, "Commune/$f") || {};
    my %ent;
    for my $sec (keys %$s) { next if $sec eq '__preamble'; $ent{$sec} = { lat => $s->{$sec}, eng => $e->{$sec} }; }
    $out{$f} = \%ent;
  }
} elsif ($mode eq 'propers') {
  my @secs = ('Ant Matutinum','Ant Laudes','Ant Vespera','Ant Vespera 3','Ant Prima','Ant Tertia','Ant Sexta','Ant Nona','Ant Completorium',
    'Ant 1','Ant 2','Ant 3','Invit','Hymnus Matutinum','Hymnus Laudes','Hymnus Vespera','Hymnus Vespera 3','Hymnus1 Matutinum','Hymnus1 Vespera',
    'Capitulum Laudes','Capitulum Vespera','Capitulum Vespera 1','Capitulum Vespera 3','Capitulum Sexta','Capitulum Nona',
    'Versum 1','Versum 2','Versum 3','Versum Tertia','Versum Sexta','Versum Nona','Versum Prima','Nocturn 1 Versum','Nocturn 2 Versum','Nocturn 3 Versum',
    'Responsory Breve Tertia','Responsory Breve Sexta','Responsory Breve Nona','Lectio Prima','Rule','Doxology','Ant 4','Ant 41','Ant 43','Oratio','Oratio 1','Oratio 2','Oratio 3','OratioW','Oratio Matutinum','Name','Commemoratio','Commemoratio 1','Commemoratio 2','Commemoratio 3',
    'Special Prima','Special Tertia','Special Sexta','Special Nona','Special Completorium','Special Vespera 1','Initial','Conclusio','Oratio mortuorum','Oratio mortuorum1','Oratio mortuorum2','Ant Matutinum 11','Ant Matutinum 12','Oratio Vigilia','Octava','Octava 1','Octava 2','Octava 3');
  for my $dir ('Sancti','Tempora') {
    opendir(my $dh, "$datafolder/Latin/$dir"); my @files = grep { /\.txt$/ } readdir($dh); closedir($dh);
    for my $f (sort @files) {
      # Resolve the file's conditionals in its own context: the winner, the
      # date of a Sancti file, the week of a Tempora file.
      $winner = "$dir/$f"; $hora = 'Laudes'; @dayname = ('', '', ''); %main::setupstring_caches_by_version = ();
      if ($dir eq 'Sancti' && $f =~ /^(\d\d)-(\d\d)/) { $month = $1 + 0; $day = $2 + 0; } else { $month = 1; $day = 1; }
      if ($dir eq 'Tempora' && $f =~ /^([A-Za-z]+\d*)/) { $dayname[0] = $1; }
      my $s = setupstring('Latin', "$dir/$f") or next;
      my $e = setupstring($L2, "$dir/$f") || {};
      my %ent;
      for my $sec (@secs) { if (defined $s->{$sec} && ($s->{$sec} =~ /\S/ || $sec =~ /^Commemoratio/)) { $ent{$sec} = { lat => $s->{$sec}, eng => $e->{$sec} }; } }
      $out{"$dir/$f"} = \%ent if %ent;
      # A section conditioned on the weekday ("feria 7"): the file as read on that weekday.
      if ($dir eq 'Sancti') {
        open(my $fh2, '<:encoding(UTF-8)', "$datafolder/Latin/$dir/$f"); local $/; my $raw2 = <$fh2>; close($fh2);
        my %dows = map { $_ => 1 } ($raw2 =~ /\(.*?feria ([1-7])/g);
        for my $fd (sort keys %dows) {
          my $dw = $fd - 1;
          %main::setupstring_caches_by_version = (); $dayofweek = $dw;
          my $ds = setupstring('Latin', "$dir/$f"); my $de = setupstring($L2, "$dir/$f") || {};
          my %dent;
          for my $sec (@secs) { if (defined $ds->{$sec} && ($ds->{$sec} =~ /\S/ || $sec =~ /^Commemoratio/)) { $dent{$sec} = { lat => $ds->{$sec}, eng => $de->{$sec} }; } }
          $out{"$dir/$f\@dow$dw"} = \%dent if %dent;
          $dayofweek = $ENV{DO_DOW} // 1;
        }
      }
      # A pseudo-commune ("ex Sancti/X") is read by DO on the referencing
      # day: dump X again in that day's context ("Sancti/X.txt@MM-DD").
      my $refm = ($dir eq 'Sancti' && $s->{Rank} =~ /ex (Sancti\/[^;\s]+)/) ? $1 : '';
      if ($refm && $f =~ /^(\d\d-\d\d)/) {
        my $md = $1; my $ref = $refm; $ref =~ s/\.txt$//;
        %main::setupstring_caches_by_version = ();
        my $rs = setupstring('Latin', "$ref.txt"); my $re = setupstring($L2, "$ref.txt") || {};
        if ($rs) {
          my %rent;
          for my $sec (@secs) { if (defined $rs->{$sec} && $rs->{$sec} =~ /\S/) { $rent{$sec} = { lat => $rs->{$sec}, eng => $re->{$sec} }; } }
          $out{"$ref.txt\@$md"} = \%rent if %rent;
        }
      }
      # A Sancti file with "(tempore paschali)" sections: its Paschaltide form too.
      if ($dir eq 'Sancti') {
        open(my $fh, '<:encoding(UTF-8)', "$datafolder/Latin/$dir/$f"); local $/; my $raw = <$fh>; close($fh);
        if ($raw =~ /paschali/i) {
          %main::setupstring_caches_by_version = (); @dayname = ('Pasc1', '', '');
          my $ps = setupstring('Latin', "$dir/$f"); my $pe = setupstring($L2, "$dir/$f") || {};
          my %pent;
          for my $sec (@secs) { if (defined $ps->{$sec} && $ps->{$sec} =~ /\S/) { $pent{$sec} = { lat => $ps->{$sec}, eng => $pe->{$sec} }; } }
          $out{"$dir/$f\@pasch"} = \%pent if %pent;
          @dayname = ('', '', '');
        }
      }
    }
  }
} elsif ($mode eq 'ants') {
  my @secs = ('Ant Matutinum','Ant Laudes','Ant Vespera','Ant Vespera 3','Ant Prima','Ant Tertia','Ant Sexta','Ant Nona','Ant Completorium');
  for my $dir ('Sancti','Tempora','Commune') {
    opendir(my $dh, "$datafolder/Latin/$dir"); my @files = grep { /\.txt$/ } readdir($dh); closedir($dh);
    for my $f (sort @files) {
      my $s = setupstring('Latin', "$dir/$f") or next;
      my $e = setupstring($L2, "$dir/$f") || {};
      my %ent;
      for my $sec (@secs) { if ($s->{$sec}) { $ent{$sec} = { lat => $s->{$sec}, eng => $e->{$sec} }; } }
      $out{"$dir/$f"} = \%ent if %ent;
    }
  }
} else {
  for my $lang ('Latin',$L2) {
    for my $f ('Special/Major Special.txt','Special/Minor Special.txt','Special/Matutinum Special.txt','Special/Prima Special.txt','Psalmi/Psalmi major.txt','Psalmi/Psalmi minor.txt','Psalmi/Psalmi matutinum.txt','Doxologies.txt','Mariaant.txt','Common/Prayers.txt','Special/Preces.txt') {
      my $s = setupstring($lang, "Psalterium/$f") or next;
      $out{"$lang/$f"} = $s;
    }
  }
}
print JSON::PP->new->utf8(0)->canonical->pretty->encode(\%out);
