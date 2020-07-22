/* Produce a list of ZIP files and their entries from a single folder */
%macro listzipcontents (
     targdir= /* a system folder that contains ZIP files       */, 
     outlist= /* output data set for list of files and members */);
  filename targdir "&targdir";
 
  /* Gather all ZIP files in a given folder                */
  /* Searches just one folder, not subfolders              */
  /* for a fancier example see                             */
  /* http://support.sas.com/kb/45/805.html (Full Code tab) */
  data _zipfiles;
    length fid 8;
    fid=dopen('targdir');
 
    if fid=0 then
      stop;
    memcount=dnum(fid);
 
    /* Find all ZIP files.  GZ files added in 9.4 Maint 5 */
    do i=1 to memcount;
      memname=dread(fid,i);
      if lowcase( scan( memname,-1,'.')) in ('zip') then
        output;
    end;
 
    rc=dclose(fid);
  run;
 
  filename targdir clear;
 
  /* get the memnames into macro vars */ 
  proc sql noprint;
    select memname into: zname1- from _zipfiles;
    %let zipcount=&sqlobs;
  quit;
 
  /* for all ZIP files, gather the members */
  %do i = 1 %to &zipcount;
    %put &targdir/&&zname&i;
    filename targzip ZIP "&targdir/&&zname&i";
 
    data _contents&i.(keep=zip memname);
      length zip $200 memname $200 ;
      zip="&targdir/&&zname&i";
      fid=dopen("targzip");
 
      if fid=0 then
        stop;
      memcount=dnum(fid);
 
      do i=1 to memcount;
        memname=dread(fid,i);
 
        /* save only full file names, not directory names */
        if (first(reverse(trim(memname))) ^='/') then
          output;
      end;
 
      rc=dclose(fid);
    run;
 
    filename targzip clear;
  %end;
 
  /* Combine the member names into a single data set        */
  /* the colon notation matches all files with "_contents" prefix */
  data &outlist.;
    set _contents:;
  run;
 
  /* cleanup temp files */
  proc datasets lib=work nodetails nolist;
    delete _contents:;
    delete _zipfiles;
  run;
 
%mend;

%macro extractAll;
	proc sql noprint;
	 select zip into: zips1 TRIMMED from allfiles;
	 select memname into: file1 TRIMMED from allfiles;
	 %let fcount=&sqlobs;
	quit;

   %do i = 1 %to &fcount;
    filename inzip ZIP "&&zips&i."; 
	/* Check for subfolders in the ZIP.  Handles just one level for now! */
	data _null_;
		if find("&&file&i.",'/')>0 then do;
		  rc = dcreate(scan("&&file&i.",1,'/'),"%sysfunc(getoption(work))");
		end;
	run;
    filename mem "%sysfunc(getoption(work))/%bquote(&&file&i.)";
    data _null_;
       infile inzip("&&file&i..") 
           lrecl=256 recfm=F length=length eof=eof unbuf;
       file mem lrecl=256 recfm=N;
       input;
       put _infile_ $varying256. length;
       return;
     eof:
       stop;
    run;
    filename mem clear;
   %end;
%mend;

/* Sample of use                                    */
/* create a data set with the zip members           */
/* TARGDIR is the OS folder where the ZIP file sits */
/* %listzipcontents(targdir=c:\temp, outlist=work.allfiles); *

/* Extract all of the files to the WORK folder */
/* %extractAll; */
