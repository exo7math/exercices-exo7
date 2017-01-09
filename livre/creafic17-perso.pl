#!/usr/bin/perl --
# Shebang qui permet de rendre le ficher executable

# Fichier perl
# Creation d'un fichier au format tex a partir d'une
# fiche brute
# En entree on a le fichier de la fiche brute
# et en sortie un fichier avec tout les enonces corrections,....
# qui sont recuperer dans les fichier ex00xxxx.txt

# Exemple d'appel par lecture d'une fiche fic_test.txt:
# ../bin/creafic16.pl -e 1 -c 2 -i 0 -f txt -n "mon_fic_sortie.txt" "fic_test.txt"
# ou alors par saisie directe des exercices (ici 7 10 14-18):
# ../bin/creafic16.pl -e 1 -c 2 -i 0 -f txt -n "mon_fic_sortie.txt" "7 10 14-18"
# options :
# -e, -i, -c position des enonces/indications/corrections (par defaut 1/1/1)
# -f format final voulu (par defaut tex)
#       txt : juste les exos,
#       tex : fichier compilable LaTeX,
#       pdf : fichier compilable pour pdfLaTeX
#       pdfi : fichier pour pdfLateX avec hyperref
#       html : fichier lisble par jsMath (pour les etudiants),
#       htmli : fichier interactif, lisble par jsMath (pour les profs).
# -t entete de la fiche
# -n nom du fichier de sortie (par defaut "fic_sortie.tex" dans le repertoire "tmp").

## Essai : ../bin/creafic16.pl -e 1 -c 2 -i 1 -f tex -t "Uni:::An:::Num:::Mod:::Titre" -n "mon_fic_sortie.tex" "7 10 14-18"
## Essai : ../bin/creafic16.pl -e 1 -c 0 -i 0 -f tex -n "../fiches/lafic00000.tex" "../fiches/fic00000.txt"
## Essai : ../bin/creafic16.pl -e 1 -c 0 -i 0 -f pdf -n "../fiches/lafic00000.tex" "../fiches/fic00000.txt"
## Essai ./creafic17.pl -e 1 -c 2 -i 2 -f pdfi -n "test11.tex" "1 3 47 60 5-7"
## Ce fichier est normalement appele à partir du repertoire tmp de publi_html


# Script pour utilisation perso (janvier 2017) depuis le repertoire '/home/arnaud/git/exercices-exo7/livre/'
## ./creafic17-perso.pl -e 1 -c 2 -i 2 -f pdfi -n "fiche_001.tex" "fic00001.txt"

use strict;

use Fcntl qw(:DEFAULT :flock);
use Getopt::Std;
use File::Temp qw/ tempfile tempdir /;

# Variables globales de recuperation des options
our ($opt_e, $opt_i, $opt_c, $opt_f, $opt_t, $opt_n); 

# Recuperations des options
getopts("e:i:c:f:t:n:");

# La presence/position des indications-corrections
# valeur 0 : NON
# valeur 1 : OUI a la suite
# valeur 2 : OUI sur une feuille a part
# Par defaut tout le monde a 1
my $posenonce = 1;
my $posindic = 1;
my $poscorrec = 1;
if (defined $opt_e) { $posenonce = $opt_e;}
if (defined $opt_i) { $posindic = $opt_i;}
if (defined $opt_c) { $poscorrec = $opt_c;}

my $entete;
if (defined $opt_t) { $entete = $opt_t;}
my $ent_univ; my $ent_annee; my $ent_num; my $ent_module; my $ent_titre;
if ($entete =~ /(.*):::(.*):::(.*):::(.*):::(.*)/) {
  $ent_univ = $1;
  $ent_annee = $2;
  $ent_num = $3;
  $ent_module = $4;
  $ent_titre = $5;
}

# Le type de fichier de sortie final
my $typefic = "tex";  # par defaut
if (defined $opt_f) { $typefic = $opt_f; }
# Autres format :
# "tex" : format latex avec preambule, entete, fin,;...
# "txt" : format brut sans preambule ni fin
# "pdf" = "tex" du tex pour pdflatex
# "html" = du tex pour jsMath
# autres...

# Recuperation de l'argument
my $typearg;
my $fichein;
my $maliste;
if ($ARGV[0] =~ /[^-\d\s]/) { 
  # C'est une fiche en entree
  $typearg = 1;
  $fichein = "\.\.\/fiches\/".$ARGV[0];
  sysopen(ficin, $fichein, O_RDONLY) or die "Impossible1 d'ouvrir $fichein $!";
  flock(ficin, LOCK_EX) or die "Erreur verrouillage $!";
} else {
  # C'est des numeros d'exercices
  $typearg = 0;
  $maliste = $ARGV[0];
}

# La fiche de sortie (peut etre  entre avec l'option -n)
my $nomficout = "\.\.\/tmp\/fic_sortie.tex";
if (defined $opt_n) { $nomficout = $opt_n; }
open(ficout, "+>", $nomficout) or die "Impossible d'ouvrir $nomficout $!";
# sysopen(ficout, $nomficout, O_WRONLY | O_CREAT) or die "Impossible3 d'ouvrir $nomficout $!";
# Fichier verouill'e
 flock(ficout, LOCK_EX) or die "Erreur verrouillage $!";

# Les fichiers temporaires pour les enonces, indications et corrections Ouverts en Lecture et Ecriture
my $dir = tempdir( CLEANUP => 1 );
my $ficoutenonce = tempfile(DIR => $dir);
my $ficoutindic = tempfile(DIR => $dir);
my $ficoutcorrec = tempfile(DIR => $dir);


# Les eventuels ajouts dans le preambule avec \addcommand
my $ajoutpreamb = "";
my $macommande;

##############################################################
## Lecture d'un exercice
sub extraction_exo {
  my $num = shift;
  # Le fichier d'exercice
  my $monenonce =  "\.\.\/exercices\/ex" . $num . ".txt";  # ouverture en ecriture ficexex0000+i.txt
  # Sauf si une fiches en html
  if (($typefic eq "html") or ($typefic eq "htmli")) {$monenonce =  "\.\.\/jhtml\/ex" . $num . ".html";};

  sysopen(ficenonce, $monenonce, O_RDONLY) or die "Impossible d'ouvrir $monenonce $!";
  # Fichier verouill'e
  #flock(ficenonce, LOCK_EX) or die "Erreur verrouillage $!";

  my $enonce = 0;  # On est dans l'enonce ? 0 False, 1 True 
  my $indic = 0;
  my $correc = 0;
  
  my $numexo;
  my $line;

  while(<ficenonce>) 
  {
    $line = $_;
    if (/\\enonce/) {
      $enonce = 1;   # True
    }
    if (/\\indication/ or /\\noindication/) {
      $indic = 1;   # True
    }
    if (/\\correction/ or /\\nocorrection/) {
      $correc = 1;   # True
    }
    
    # commande pour pdfi 
    if ($typefic eq "pdfi") {
      # recuperation du numero absolu de l'exo en cours 
      if (/\\exercice\{(\d{1,6})/) {$numexo=sprintf("%0*d",6,$1)};  
      $line =~ s/\\enonce\[(.*)\]/\\bidonenonce{$numexo}{$1}/;        
      $line =~ s/\\enonce/\\enonce{$numexo}{}/;   
      $line =~ s/\\bidonenonce/\\enonce/;       
      $line =~ s/\\finenonce/\\finenonce{$numexo}/; 
      $line =~ s/\\indication/\\indication{$numexo}/;                
      $line =~ s/\\correction/\\correction{$numexo}/;                      
    };
    
     
    # Gestion des commandes supplementaires
    if (/\\addcommand\{(.*)\}$/) {
      $macommande = $1; 
      if (index($ajoutpreamb,$macommande) < 0)
      {
        $ajoutpreamb = $ajoutpreamb.$macommande."\n";
      }
    }

   # Affiche la ligne a la suite s'il le faut
    if ( (!$enonce and !$indic and !$correc) or ($enonce and ($posenonce==1)) or ($indic and ($posindic == 1)) or ($correc and ($poscorrec == 1))) {
      print $ficoutenonce $line;
    }

    # Affiche la ligne a part s'il le faut
    if ($indic and ($posindic == 2)) {
      print $ficoutindic $line;
    }
    if ($correc and ($poscorrec == 2)) {
      print $ficoutcorrec $line;
    }

   if (/\\finenonce/) {
      $enonce = 0;   
    }
    if (/\\finindication/ or /\\noindication/) {
      $indic = 0;   
    }
    if (/\\fincorrection/ or /\\nocorrection/) {
      $correc = 0;   
    }
  }
  close(ficenonce);
}

##############################################################
## Boucle pour un requete
sub boucle {
  my @liste = @_;
  foreach(@liste) 
  {
    if (/-/)
    {
      my @interval = split /-/, $_;     # une requete du type 17-19
      for (my $i=$interval[0]; $i<= $interval[1]; $i++)
      {
        my $num = sprintf("%0*d",6,$i); # format 0000+i
        extraction_exo($num);
      }
    }
    else {
      my $num = sprintf("%0*d",6,$_);    # un seul exo au format 23
      extraction_exo($num);
    }
  }
}

##############################################################
## Lecture de tous les exercices demandes dans la liste ou dans la fiche source
if ($typearg==0) {
  # Ecriture propre des numeros de la liste et decoupage
  $maliste =~ s/\s+/ /g;  # Suppression des espaces doubles
  $maliste =~ s/^\s//;    # Suppression des espaces au debut
  $maliste =~ s/\s$//;    # Suppression des espaces a la fin
  $maliste =~ s/\s*-\s*/-/g; # Suppression des espaces autour des tirets

  if (($typefic eq "html") or ($typefic eq "htmli"))  { 
    print $ficoutenonce "<br><i> Cette fiche contient les exercices : $maliste <\/i><br><br>\n\n";
  } else { print $ficoutenonce "\% Cette fiche contient les exercices : $maliste \n\n";};
  
  my @laliste = split /\s/, $maliste; # Decoupage selon les espaces
  boucle(@laliste);
} 
else 
{
  while(<ficin>) {
    if (!(/\s*%\s*\\insertion/) and (/\\insertion\{(.*)\}/))
    # cela exclut les lignes commentees % \insertion{...}
    {
      my @laliste = split /,/, $1;
      boucle(@laliste);
    }
    else { # on imprime quand meme le reste de la fiche (??)
      print $ficoutenonce $_;
    }
        # Gestion des commandes supplementaires des fiches
    if (/\\addcommand\{(.*)\}$/) {
      $macommande = $1; 
      if (index($ajoutpreamb,$macommande) < 0)
      {
        $ajoutpreamb = $ajoutpreamb.$macommande."\n";
      }
    }
  }
}

######################################################
# Gestion du fichier de sortie en fonction de la position
# et du format


# Lecture du preambule si necessaire

if (($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdfi") or ($typefic eq "html")  or ($typefic eq "htmli")) {
#  my $fichepreamb = "\.\.\/bin\/$typefic"."_preamb.txt";  # Ouverture du preambule adequat
#  my $fichepreamb = "\.\.\/bin\/tex_preamb.txt"; 
  my $fichepreamb = "$typefic"."_preamb.txt";  # PERSO 2017
  sysopen(ficpreamb, $fichepreamb, O_RDONLY) or die "Impossible1 d'ouvrir $fichepreamb $!";
  #flock(ficpreamb, LOCK_EX) or die "Erreur verrouillage $!";
  while (<ficpreamb>) {
    print ficout $_;
  }  
  close(ficpreamb);


  if (($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdfi")) {
    # Ajout des commandes suplementaires au preambule
    print ficout $ajoutpreamb."\n";
  }
  
  if ((defined $opt_t) and ($entete =~ /[^:\s]/) and (($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdf")) ) {
    print ficout "\\begin\{document\}\n\n";
    print ficout "\\textsf\{\\textbf\{".$ent_annee."\}\} \\hfill\\textsf\{\\textbf\{".$ent_num."\}\}\n\n";
    print ficout "\\textsf\{\\textbf\{".$ent_univ."\}\} \\hfill\\textsf\{\\textbf\{".$ent_module."\}\}\n\n";
    print ficout "\\vspace*\{0.5ex\}\\hrule\\vspace*\{1.5ex\}\n";
    print ficout "\\hfil\\textsf\{\\textbf\{\\Large ".$ent_titre;
    print ficout "\}\}\n\\vspace*\{1ex\}\\hrule\\vspace*\{5ex\}\n";

  } else { 
    #my $fichedeb = "\.\.\/bin\/$typefic"."_debut.txt"; 
    my $fichedeb = "$typefic"."_debut.txt"; # PERSO 2017
    sysopen(ficdeb, $fichedeb, O_RDONLY) or die "Impossible1 d'ouvrir $fichedeb $!";
    #flock(ficdeb, LOCK_EX) or die "Erreur verrouillage $!";
    while (<ficdeb>) {
      print ficout $_;
    }  
    close(ficdeb);
  }
}
  
# Lecture enonce/indication/correction
seek($ficoutenonce,0,0) or die "Erreur $!";
seek($ficoutindic,0,0) or die "Erreur $!";
seek($ficoutcorrec,0,0) or die "Erreur $!";

# Lecture des enonces 
my $line;
if (($typefic eq "txt") or ($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdfi")) {
  while (<$ficoutenonce>) {
    print ficout $_;
  }
  if ($typefic eq "pdfi") {print ficout "\n\n \\finenonces \n\n";};
}



my $mynumexo=1;

if (($typefic eq "html") or ($typefic eq "htmli")) {
  while (<$ficoutenonce>) {
   $line = $_;
   # Remplacement des balises des exercices

   if ($typefic eq "html") {     
    if ($line=~ /\\exercice\{(\d{1,6})/) {$mynumexo=$1};
    $line=~ s/\\exercice\{(\d{1,6}),\s(\w{1,10}),\s(\d\d\d\d)\/(\d\d)\/(\d\d)\}/<div class="exercicehtml"><h3>Exercice $1<\/h3>\n/go;
   }

   if ($typefic eq "htmli") {
     if ($line=~ /\\exercice\{(\d{1,6})/) {$mynumexo=$1};
     $line=~ s/\\exercice\{(\d{1,6}),\s(\w{1,10}),\s(\d\d\d\d)\/(\d\d)\/(\d\d)\}/
<input type="checkbox" name = laliste[] id="checkbox$1" checked value=$1>\n
<div class="exercicehtml"> \n <label for="checkbox$1">\n<h3> Exercice $1<\/h3>\n <div class="auteurhtml"> Auteur : $2, date : $3\/$4\/$5 <\/div>
<div class="modifhtml"><a href="mailto:exo7\@emath.fr\?subject=\[Exo7\] Erreur exercice $1"> Signaler une erreur<\/a> &nbsp &nbsp &nbsp &nbsp
<a href=https:\/\/exo7.emath.fr\/doku.php\?id=presexo:prXXX$1
target="_blank" >Modifier l'exercice $1<\/a> <\/div>
<\/label> 
<br>\n/go;
 $line =~ s/XXX(\d{1,6})/sprintf("%0*d",6,$1)/eg;

     }

    $line=~ s/\\finexercice/<\/div><br\/><br\/>/go;
    $line=~ s/\\enonce/<div class="enonce">/go;
    $line=~ s/\\finenonce/<\/div><br>/go;
    $line=~ s/\\indication/<h4 onclick="montre_div('indic$mynumexo');">Indication<\/h4> <div class="indicationhtml" id="indic$mynumexo">/go;
    $line=~ s/\\finindication/<\/div>/go;
    $line=~ s/\\noindication/<br><i> Pas d'indication.<\/i><br>/go;
    $line=~ s/\\correction/<h4 onclick="montre_div('correc$mynumexo');">Correction<\/h4> <div class="correctionhtml" id="correc$mynumexo">/go;
    $line=~ s/\\fincorrection/<\/div><br>/go;
    $line=~ s/\\nocorrection/<br><i> Pas de correction.<\/i><br>/go;
   # Remplacement des balises des fiches
    $line=~ s/\\fiche\{(.*)\}//go;
    $line=~ s/\\finfiche//go;
    $line=~ s/\\titre\{(.*)\}/<h1>$1<\/h1>/go;
    $line=~ s/\\section\{(.*)\}/<h2>$1<\/h2>/go;
    $line=~ s/\\subsection\{(.*)\}/<h3>$1<\/h3>/go;
    
    $line=~ s/\\shadowbox//go;   
    $line=~ s/\\begin\{center\}//go;
    $line=~ s/\\end\{center\}//go;
     
  print ficout $line;
  }
}

# Lecture des indications
if (($posindic == 2) and (($typefic eq "tex") or ($typefic eq "pdf") )) {
  print ficout "\n\n\\newpage\n\n";
}

if (($posindic == 2) and ($typefic eq "pdfi")) {
  print ficout "\n\n \\finindications \n\n";
}

if (($posindic == 2) and (($typefic eq "html") or ($typefic eq "htmli")) ) {
  print ficout "<br><br>";
}

if (($typefic eq "txt") or ($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdfi")) {
  while (<$ficoutindic>) {
    print ficout $_;
  }
}
if (($typefic eq "html") or ($typefic eq "htmli")){
  while (<$ficoutindic>) {
   $line = $_;
   # Remplacement des balises des exercices
    $line=~ s/\\indication/<div>/go;
    $line=~ s/\\finindication/<\/div>/go;
    $line=~ s/\\noindication/<div><i> Pas d'indication.<\/i><\/div>/go;
  print ficout $line;
  }
}

# Lecture des corrections
if (($poscorrec == 2) and (($typefic eq "tex") or ($typefic eq "pdf")  or ($typefic eq "pdfi"))) {
  print ficout "\n\n\\newpage\n\n";
}

if (($poscorrec == 2) and (($typefic eq "html")or ($typefic eq "htmli")) ) {
  print ficout "<br><br>";
}

if (($typefic eq "txt") or ($typefic eq "tex") or ($typefic eq "pdf") or ($typefic eq "pdfi")) {
  while (<$ficoutcorrec>) {
    print ficout $_;
  }
}
if (($typefic eq "html") or ($typefic eq "htmli")) {
  while (<$ficoutcorrec>) {
   $line = $_;
   # Remplacement des balises des exercices
    $line=~ s/\\correction/<div>/go;
    $line=~ s/\\fincorrection/<\/div>/go;
    $line=~ s/\\nocorrection/<div><i> Pas de correction.<\/i><\/div>/go;
  print ficout $line;
  }
}

# Fin par \end{document}
if (($typefic eq "tex") or ($typefic eq "pdf")  or ($typefic eq "pdfi")) {
  print ficout "\n\n\\end\{document\}\n\n";
}
if ($typefic eq "html") {
  print ficout "\n\n<\/body>\n<\html>\n";
}

if ($typefic eq "htmli") {
  print ficout "\n <\/div>  \n";
  print ficout "\n <p> \n <input type=\"submit\" value=\"    Ok    \">\n";
 # print ficout "<input type=\"reset\" value=\" Effacer \"> \n";
  print ficout "<\/p>\n";
  print ficout "\n<\/form>\n<\/body>\n<\html>\n";
}


close(ficin);
close(ficout);
close($ficoutenonce);
close($ficoutindic);
close($ficoutcorrec);





