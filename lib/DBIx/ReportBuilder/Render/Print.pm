# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/Print.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 8306 $ $DateTime: 2003/09/29 00:54:37 $

package DBIx::ReportBuilder::Render::Print;
use base 'DBIx::ReportBuilder::Render';
use strict;
use NEXT;

# XXX - eventually make this the baseclass for PDF, Print and MSWord

use File::Spec;
use File::Temp 'mkdtemp';
use MIME::Base64 'decode_base64';

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(
	%args,
	twig_handlers => {
	    head	=> \&head,
	    body	=> sub { $_->set_att( dir => 'ltr' ) },
	    header      => sub {
		$_->att('hidden') ? $_->delete : do {
		    $_->set_tag('div'); $_->set_att( type => 'header' );
		    $_->set_att( style => 'border-bottom: 1px black solid' )
			if $_->att('separator');
		};
	    },
	    footer      => sub {
		$_->att('hidden') ? $_->delete : do {
		    $_->set_tag('div'); $_->set_att( type => 'footer' );
		    $_->set_att( style => 'border-top: 1px black solid' )
			if $_->att('separator');
		};
	    },
	    preamble	=> sub { $_->att('hidden') ? $_->delete : $_->erase },
	    content	=> sub { $_->att('hidden') ? $_->delete : $_->erase },
	    postamble	=> sub { $_->att('hidden') ? $_->delete : $_->erase },
	    var		=> \&var,
	    %{$args{twig_handlers}||{}},
	},
	start_tag_handlers => {
	    %{$args{start_tag_handlers}||{}},
	},
	end_tag_handlers => {
	    %{$args{end_tag_handlers}||{}},
	},
	twig_roots	=> {
	    'html'	=> 1,
	    %{$args{twig_roots}||{}},
	},
	pretty_print	=> ($args{pretty_print} || 'indented_c'),
    );

    return $self;
}

# XXX do a temporary juxtaposision
sub Render {
    my $basedir = File::Spec->catdir(File::Spec->tmpdir, 'RG');
    mkdir $basedir, 0777 unless -d $basedir;
    my $tmpdir = mkdtemp(File::Spec->catdir($basedir, 'XXXXXXXX')) or die $!;

    my $out = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">' .
		$_[0]->root->sprint;

    my $cnt = 1;
    while ($out =~ s{src="data:image/png;base64,([^"]+)"}{src="$cnt.png"}) {
	open my $fh, ">$tmpdir/$cnt.png" or die $!;
	binmode ($fh);
	print $fh decode_base64($1);
	$cnt++;
    }

    open my $fh, ">$tmpdir/out.html" or die $!;
    print $fh $out;
    close $fh;

    my $absdir = File::Spec->rel2abs($tmpdir);
    $absdir =~ s{^(\w):}{/$1:}g;
    $absdir =~ s{\\}{/}g;
    my $convert = File::Spec->catfile(
	$basedir, substr($tmpdir, -8) . '.htm'
    );
    open $fh, ">$convert" or die $!;
    binmode($fh);
    my $macro = +PrintConverter();
    $macro =~ s/\$PATH/$absdir/g;
    print $fh $macro;
    close $fh;

    if ($^O eq 'MSWin32') {
	for (1..60) {
	    last if -s "$tmpdir/out.prn";
	    sleep 1;
	}
	sleep 1;
    }
    else {
	system(
	    ($ENV{SWRITER} || ($^O eq 'MSWin32'
		? "C:/Progra~1/OpenOf~1.0/program/soffice.exe"
		: "/usr/local/OpenOffice.org1.1.0/program/swriter")),
	    $convert,
	);
    }
    for (1..10) {
	last if -s "$tmpdir/out.prn";
	sleep 1;
    }

    unlink "$tmpdir/out.prn";
    unlink "$tmpdir/out.html";
    rmdir $tmpdir;
    return 1;
}

my %VarAtt = (
    date	=> [qw( type datetime   sdnum   1028;1033;MM/DD/YYYY ) ],
    time	=> [qw( type datetime   sdnum   1028;1033;HH:MM:SS ) ],
    page	=> [qw( type page	subtype random	format arabic ) ],
    page_count	=> [qw( type docstat	subtype page	format arabic ) ],
);

sub var {
    my $self = shift;
    my $item = $_;
    $self->NEXT::var(@_);
    $item->set_tag('sdfield');
    $item->set_att(@{ $VarAtt{$item->att('name')} || [] });
}

sub head {
    my $self = shift;
    $_->insert_new_elt(
	'meta' => {
	    'http-equiv'    => 'content-type',
	    'content'	    => 'text/html; charset=utf-8',
	}
    );
    $_->insert_new_elt(
	style => {}, $self->HeadDimensions($_)
    );
}

1;

use constant PrintConverter => q{
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
<HEAD>
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<TITLE>Print Converter</TITLE>
<META HTTP-EQUIV="CONTENT-SCRIPT-TYPE" CONTENT="text/x-StarBasic">
<SCRIPT LANGUAGE="StarBasic">
<!--
' $LIBRARY: Standard
' $MODULE: HTML2Print
Sub HTML2Print
    Dim oDesktop As Object
    Dim sInDir As String
    Dim sOutDir As String
    Dim sFile As String
    Dim sURL As String
    Dim sPrint As String
    Dim oDocument As Object   

    On Error Resume Next

    sInDir = "file://$PATH/"
    sOutDir = "file://$PATH/"

    Dim aLoad(0) As New com.sun.star.beans.PropertyValue
    aLoad(0).Name  = "Hidden"
    aLoad(0).Value = True

    Dim aPrint(0) As New com.sun.star.beans.PropertyValue

    oDesktop = createUnoService("com.sun.star.frame.Desktop")
    sFile = Dir(sInDir+"*.html")

    While sFile <> ""
	sURL = sInDir + sFile
	oDocument=oDesktop.loadComponentFromURL(sURL, "_blank", 0, aLoad())
	sPrint = sOutDir + Left(sFile, Len(sFile)-5) + ".prn"
	oDocument.print(aPrint())
	oDocument.storeToURL(sPrint,aStore())
	oDocument.dispose()
	sFile = Dir
    Wend 
    StarDesktop.currentComponent.dispose()
End Sub

' -->
</SCRIPT>
</HEAD>
<BODY LANG="" DIR="LTR" SDONLOAD="Standard.HTML2Print.HTML2Print"></BODY>
</HTML>
};
