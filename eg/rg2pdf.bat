@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
..\..\..\common\perl\bin\perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
..\..\..\common\perl\bin\perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15
use strict;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../rt/local/lib";
my $basedir = File::Spec->catdir($ENV{WINDIR}, 'TEMP', 'RG');
while (1) {
    sleep 1;
    # print "Looking into $basedir\n";
    foreach my $file (<$basedir/*.htm>) {
	open FH, $file or next;
        my $path;
	my ($is_msword, $is_msexcel, $is_print);
	while (<FH>) {
	    $is_msword = 1 if m{HTML2MSWord};
	    $is_msexcel = 1 if m{HTML2MSExcel};
	    $is_print = 1 if m{HTML2Print};
	    last if ($path) = m{"(file://.*)/"};
        }
        close FH;
        print "Processing $file on $path\n";

	require Win32::OLE;
	my $objServiceManager = Win32::OLE->new(
	    "com.sun.star.ServiceManager"
	) or die $!;
	my $objDesktop = $objServiceManager->createInstance(
	    "com.sun.star.frame.Desktop"
	);

	my $v1 = $objServiceManager->Bridge_GetStruct(
	    "com.sun.star.beans.PropertyValue"
	);

	$v1->{Name} = "Hidden";
	$v1->{Value} = 1;
	my $params = [ $v1 ];

	if ($is_msexcel or $is_msword) {
	    my $v2 = $objServiceManager->Bridge_GetStruct(
		"com.sun.star.beans.PropertyValue"
	    );
	    $v2->{Name} = "FilterName";
	    $v2->{Value} = "HTML (StarCalc)" if $is_msexcel;
	    $v2->{Value} = "HTML (StarWriter)" if $is_msword;
	    push @$params, $v2;
	}


	my $objDocument = $objDesktop->loadComponentFromURL(
	    "$path/out.html", "_blank", 0, $params,
	);

	if ($objDocument) {
	    if ($is_msword) {
		$v1->{Name} = "FilterName";
		$v1->{Value} = "MS Word 97";
		$objDocument->storeToURL( "$path/out.doc", [$v1] );
	    }
	    elsif ($is_msexcel) {
		$v1->{Name} = "FilterName";
		$v1->{Value} = "MS Excel 97";
		$objDocument->storeToURL( "$path/out.xls", [$v1] );
	    }
	    elsif ($is_print) {
		$objDocument->print( [] );
		$objDocument->storeToURL( "$path/out.prn", [] );
	    }
	    else {
		$v1->{Name} = "FilterName";
		$v1->{Value} = "writer_web_pdf_Export";
		$objDocument->storeToURL( "$path/out.pdf", [$v1] );
	    }
	    $objDocument->dispose;
	}

        unlink $file;
    }
}
