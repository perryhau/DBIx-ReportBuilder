#!/usr/bin/env perl
# $File: //member/autrijus/DBIx-ReportBuilder/Makefile.PL $ $Author: autrijus $
# $Revision: #1 $ $Change: 7952 $ $DateTime: 2003/09/07 20:09:05 $

use 5.006;
use inc::Module::Install;

include_deps   ('Test::More', 5.006);
build_requires ('Test::More', 0);

warn << '.';
### PLEASE NOTE ##############################################

This is *PRE-ALPHA* code.  Until the eventual release of the
"RT Report Extenison", using this module for anything (except
for learning purporses) is strongly discouraged.

##############################################################
.

WriteMakefile (
    AUTHOR	    => 'Autrijus Tang (autrijus@autrijus.org)',
    NAME	    => 'DBIx::ReportBuilder',
    ABSTRACT	    => 'Interactive SQL report generator',
    VERSION_FROM    => 'lib/DBIx/ReportBuilder.pm',
    PREREQ_PM       => {
        'DBIx::SearchBuilder'	=> '0.90',
	'XML::Twig'		=> '3.00',
    },
);
