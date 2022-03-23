proc datasets lib = work kill nolist ; run; quit; 
options nomprint nomprintnest ;
options missing="" ;



/*DMマニュアルチェック用データ作成とCSVエクスポート*/
%macro set_dmReview2(ds,outFileName,SettingFileName,CodeName,VisitName,RepeatName);

	/*設定ファイルから設定データ抽出*/
	%setting_DS(&SettingFileName.);
	/*フォーマットカタログ作成*/
	%IF %SYSFUNC(EXIST(WORK.DATA_CODE)) %THEN %DO;
	  /*  SASデータセットSASUSER.CLASSが存在する場合、戻り値は1 */
	  proc format cntlin=Data_code;
	  run;
	%END;

%put &outFileName.;


	/*データ抽出*/
	data _NULL_;
		set Data_val end=_EOF;
		if _EOF then call symputx("OBSA",_N_);
		call symputx (cats("A",_N_),MAINCODE);
		call symputx(cats("B",_N_),LABEL);
		call symputx(cats("C",_N_),SUBCODE);
		call symputx(cats("FORMAT",_N_),FORMAT);
	run;

	%let VAL= SUBJID KVTBLID KVSETCT ;
	%let LEN = ;
	data AAA;
		set inds._TU_COW_TMRREPT2;
			%do i=1 %to &OBSA.;
				if KVITMID="&&A&i" then output;
			%end;
	run;

	/*変数名変換*/
	data AAA;
		set AAA;
			%do i=1 %to &OBSA.;
				if &CodeName.="&&A&i" then &CodeName. = "&&C&i";
				%let VAL = &VAL.  &&C&i;
				%let LEN = &LEN.  &&C&i $200.;
			%end;
	run;
	/*VISIT変換*/
	data _NULL_;
		set Data_visit end=_EOF;
		if _EOF then call symputx("OBS",_N_);
		call symputx (cats("D",_N_),VISIT);
		call symputx(cats("E",_N_),VISIT2);
	run;
	data AAA;
		set AAA;
			%do i=1 %to &OBS.;
				if &VisitName. ="&&D&i" then &VisitName. = "&&E&i";
			%end;
	run;
	data AAA2;
		set AAA;
			rename &CodeName. = SUBCODE;
	run;

	/*ひな形と結合*/

	proc sort data = AAA2; by SUBJID KVTBLID KVSETCT ;run;
	proc transpose data = AAA2 out = BBB(drop= _NAME_);
		var  KVDATAV;
		by SUBJID &VisitName. &RepeatName.  ;
		id SUBCODE;
	run;
	data CCC;
		length &LEN.;
		set _hr BBB;
		if _N_ = 1 then delete;
	run;

			data &ds.;
					set CCC;
			run;

		data &ds.2;
			set &ds.;
			%do i=1 %to &OBSA.;
				%if &&FORMAT&i ^=  %then %do;
					format &&C&i..a &&FORMAT&i... ;
					&&C&i..a = input( &&C&i. ,best.) ;
					drop &&C&i.;
					rename &&C&i..a = &&C&i.;
					
				%end;
				label  &&C&i = &&B&i;
			%end;
		run;
		data &ds.3;
			format &VAL.;
			set &ds.2;
			%do i=1 %to &OBSA.;
				label  &&C&i = &&B&i;
			%end;
		run;


		

		%Export_CSV(&ds.3,&outFileName.);
%mend;
%macro setting_DS(SetData);

			data _S_DS;
			  length  VAR1 $100. VAR2 $100. VAR3 $100. VAR4 $20.;
			  infile "&CSV_data.\&SetData."  dlm=',' dsd missover lrecl = 30000 firstobs = 1 ;
			  input VAR1	VAR2 VAR3 VAR4;
			run;
		data _NULL_;
			set _S_DS end=_EOF;
			if VAR1 = "**** Setting Variables ****" then call symputx("sVAL",_N_);
			if VAR1 = "**** Setting Visits ****" then call symputx("sVISIT",_N_);
			if VAR1 = "**** Setting Code List ****" then call symputx("sCODE",_N_);
			if _EOF then call symputx("CODEOBS",_N_);
		run;
		
		%let  sVAL = %EVAL(&sVAL+2);
		%let  sVISIT = %EVAL(&sVISIT+2);
		%let  sCODE = %EVAL(&sCODE + 2);
		%let  eVAL = %EVAL(&sVISIT -3);
		%let  eVISIT = %EVAL(&sCODE -2);

		data data_Val;
			set _S_DS (firstobs  = &sVAL.  obs  = &eVAL.);
			rename VAR1 = MAINCODE
						VAR2 = LABEL
						VAR3= SUBCODE
						VAR4= FORMAT;
		run;			

		data data_VISIT;
			set _S_DS (firstobs  = &sVISIT.  obs  = &eVISIT.);
			drop VAR3 VAR4;
			rename VAR1 = VISIT
						VAR2 = VISIT2;

		run;
		%put &sCODE. ; 
		%if %EVAL(&sCODE. < &CODEOBS.) %then %do;
			data data_CODE;
				set _S_DS (firstobs  = &sCODE. );
				drop VAR4;
				rename VAR1 = FMTNAME
							VAR2 = START
							VAR3= LABEL;
			run;
		%end;

		data _hr;
			set data_Val;
			keep SUBCODE ;
		run;
		proc sort data = _hr nodupkey; by SUBCODE; run;
		proc transpose data = _hr out= _hr(drop = _NAME_ ) ;
			var SUBCODE;
			id SUBCODE;
		run;

%mend setting_DS;

/*チェック結果をCSVでエクスポート*/
%macro Export_CSV(Ds,csv_name);
	PROC EXPORT DATA= &ds. OUTFILE= "&DM_Data.\&csv_name..csv" DBMS=CSV REPLACE LABEL; PUTNAMES=YES; RUN;
%mend;

%set_dmReview2(DM,&&_today4._&Site._01_患者背景,_DM.csv,KVITMID,KVTBLID,KVSETCT);




/*チェック結果をExcelでエクスポート*/
ods excel file="&DM_Data.\&&_today4._&Site._review.xlsx" ;
    proc print data=DM3 label;
    run;
ods excel close;


