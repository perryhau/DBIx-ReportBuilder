# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/PDF.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 8203 $ $DateTime: 2003/09/22 09:10:06 $

package DBIx::ReportBuilder::Render::PDF;
use base 'DBIx::ReportBuilder::Render';
use strict;
use NEXT;

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
	    header      => sub { $_->set_tag('div'); $_->set_att( type => 'header' ) },
	    footer      => sub { $_->set_tag('div'); $_->set_att( type => 'footer' ) },
	    preamble	=> sub { $_->erase },
	    content	=> sub { $_->erase },
	    postamble	=> sub { $_->erase },
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
    mkdir $basedir, 0755 unless -d $basedir;
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
    my $macro = +PDFConverter();
    $macro =~ s/\$PATH/$absdir/g;
    print $fh $macro;
    close $fh;

    if ($^O eq 'MSWin32') {
	for (1..10) {
	    sleep 1;
	    last if -s "$tmpdir/out.pdf";
	}
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
	last if -s "$tmpdir/out.pdf";
	sleep 1;
    }

    open $fh, "$tmpdir/out.pdf" or die "$!: $? ($tmpdir)";
    binmode($fh);
    local $/;
    my $rv = <$fh>;
    close $fh;
    unlink "$tmpdir/out.pdf";
    unlink "$tmpdir/out.html";
    rmdir $tmpdir;
    return $rv;
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
    $_->insert_new_elt(
	'meta' => {
	    'http-equiv'    => 'content-type',
	    'content'	    => 'text/html; charset=utf-8',
	}
    );
    $_->insert_new_elt(
	style => {}, '
	    @page { size: 21cm 29.7cm; margin: 2cm }
	    P { margin-bottom: 0.21cm }
	    TH P { margin-bottom: 0.21cm; font-style: italic }
	    TD P { margin-bottom: 0.21cm }
	'
    );
}

1;

use constant PDFConverter => q{
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
<HEAD>
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<TITLE>PDF Converter</TITLE>
<META HTTP-EQUIV="CONTENT-SCRIPT-TYPE" CONTENT="text/x-StarBasic">
<SCRIPT LANGUAGE="StarBasic">
<!--
' $LIBRARY: Standard
' $MODULE: HTML2PDF
Sub HTML2PDF
    Dim oDesktop As Object
    Dim sInDir As String
    Dim sOutDir As String
    Dim sFile As String
    Dim sURL As String
    Dim sPDF As String
    Dim oDocument As Object   

    On Error Resume Next

    sInDir = "file://$PATH/"
    sOutDir = "file://$PATH/"

    Dim aLoad(0) As New com.sun.star.beans.PropertyValue
    aLoad(0).Name  = "Hidden"
    aLoad(0).Value = True

    Dim aStore(1) As New com.sun.star.beans.PropertyValue
    aStore(0).Name  = "FilterName"
    aStore(0).Value = "writer_web_pdf_Export"
    aStore(1).Name  = "CompressMode"
    aStore(1).Value = 1 'Possible Values : 0 - 1 -2

    oDesktop = createUnoService("com.sun.star.frame.Desktop")
    sFile = Dir(sInDir+"*.html")

    While sFile <> ""
	sURL = sInDir + sFile
	oDocument=oDesktop.loadComponentFromURL(sURL, "_blank", 0, aLoad())
	sPDF = sOutDir + Left(sFile, Len(sFile)-5) + ".pdf"

	oDocument.storeToURL(sPDF,aStore())
	oDocument.dispose()

	sFile = Dir
    Wend 
    StarDesktop.currentComponent.dispose()
End Sub

' -->
</SCRIPT>
</HEAD>
<BODY LANG="" DIR="LTR" SDONLOAD="Standard.HTML2PDF.HTML2PDF"></BODY>
</HTML>
};
