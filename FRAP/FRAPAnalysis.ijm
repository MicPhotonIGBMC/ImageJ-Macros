/*Macro written by Elvire GUIOT - 30/07/2019 
The macro	- load a time sequence of images recorded with Metamorph from a .tif of the list 
			- ask to user to draw an ROI backgroung
			-ask to user to draw an ROI for quantification and analysis of the bleaching
			-ask to user to select a .rgn file with the FRAP metamorph ROI
			-plot the 3 curves
			-extract the mean intensity values and create a txt files with the raw datas

			-substract the bacgrund
			-noramilze the curve and correct with the bleaching
			-fit with a double exponential + offset
			-plot
			-creat a txt fikle with the results
			-save the fit plot
			

*/

var numero;					/*numero de l'image dans le nom de fichier*/
var FilePath;					/*chemin d'acces au répertoire contenant les données*/
var ParentPath; 					/* dossier contenant les données*/
var BaseName;				/*nom de base du fichier .tif*/
var nbSliceStack;    			/*nombre d'images dans la stack*/
var SequenceName;				/*nom de la pile d'images en temps*/
var imageTime = newArray(nbSliceStack);	
var BackMean;

macro "Load_FRAP_Sequence [1]"
{
/* ------------------------------------------------------------------------------------------------------------------*/
/*Ouverture de la premiere image pour recup pathway, basename, charge toutes les piles d'images au cours du temps---*/
/* ----------------------------------------------------------------------------------------- -----------------------*/
	
	while (nImages>0) { 
          selectImage(nImages); 
          close(); 
      	} 


	FilePath		= File.openDialog("Select a File");					/*recup pathway*/
	ParentPath	= File.getParent(FilePath);								/*recup dossier ou sont les datas */
	FileName	= File.getName  (FilePath);								/* recup nom complet de l'image */
	BaseName	= substring(FileName, 0, lastIndexOf(FileName, "_t"))+"_";    /*recup du nom de base */
	SequenceName=substring(FileName, 0, lastIndexOf(FileName, "_t"));  

/* -----------------------------------------------------------------------------------------------------------------*/
/*                        Recup du parametre temps dans la sequence d'images                                    */
/* ----------------------------------------------------------------------------------------- -----------------------*/
	
	setBatchMode(true);
	open(ParentPath + "\\"+ SequenceName + "_t1.tif");
	t0	= getImageTime();
	
	
	test=1;
	i=1;	
	while (test==1)
	{
		i=i+1;
		test=File.exists(ParentPath + "\\"+ SequenceName + "_t" + i + ".tif");
		if (test ==1) open(ParentPath + "\\" + SequenceName + "_t" + i + ".tif");		//load toutes les images
			} 
	run("Images to Stack", "name=[" + SequenceName + "] title=[] use");
	setBatchMode("exit and display");
	
	nbSliceStack=nSlices;

	imageTime = newArray(nbSliceStack);						/*prep une table pour le temps réel de la sequence d'images*/

	setSlice(1);
	t0				= getImageTime();						/* t0*/
	imageTime[0]	= 0;

for(i = 2; i < =nbSliceStack; i++)
	{
		setSlice(i);
		imageTime[i - 1] = getImageTime() - t0;				/*recup des valeurs de temps pour chaque image - t0*/
//		print (imageTime[i-1]);
	}

/*	print ("RealTime (sec) for ImageSeries ", SequenceName);   // creat a txt file with the time datas 
	for(i=1;i<=nSlices;i++) print( imageTime[i-1]);
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_RealTime.txt";
		saveAs("Text", resName);


/* -----------------------------------------------------------------------------------------------------------------*/
/*                                                   ROI manager                                                   */
/* ----------------------------------------------------------------------------------------- -----------------------*/
	setSlice(20);
	
	run("ROI Manager...");					
	roiManager("reset");


	setTool("rectangle");
	waitForUser("Draw ROI background - Press OK when DONE");
	roiManager("Add");
	roiManager("Select", 0 );
	roiManager("Rename", "Background");				/* ROI background*/
	setTool("polygon");
	waitForUser(" Add the ROI for bleaching Correction - Press OK when DONE");
	roiManager("Add");
	roiManager("Select", 1 );
	roiManager("Rename", "Ref");	

	Dialog.create("ROI for Frap Analysis");																// si existe .rgn Metamorph, charge les coordonnées de la zone, sinon user dessine et add			
	items = newArray("YES", "NO");
	Dialog.addRadioButtonGroup(".rgn Metamorph File exists?", items, 1, 1, "YES");
	Dialog.show();
	choix = Dialog.getRadioButton();
	test =  matches (choix,"YES") ;
			if (test ==1){
	 		roiFile	= File.openAsString("");   // Get the FRAP ROI  from the .rgn Metamorph  file			
			rois	= split(roiFile, "\t\n\r");
				for(j = 0; j != rois.length; j++)
		                       createROI(rois[j], j);						 
	 		}
	 			else {
	 		waitForUser(" Add the ROI for FRAP analysis - Press OK when DONE");
	 		roiManager("Add");
	 		}
		
	roiManager("Select", 2 );
	roiManager("Rename", "Frap");

	roiManager("Sort");																					//pour que les ROI soient toujours dans le m^me ordre car appelées ensuite selon leur index		

/* -----------------------------------------------------------------------------------------------------------------*/
/*                                                  plot Raw datas                                                */
/* ----------------------------------------------------------------------------------------- -----------------------*/


		Back = newArray(nSlices);
		Ref  = newArray(nSlices);
		Frap = newArray(nSlices);
		selectWindow(SequenceName);
/* création des tables de mesures des intensités dans les ROIs*/		
			for (i = 0; i != nSlices; i++)
				{ 
			num=i+1;
			roiManager("Select", 0);
			setSlice (num);
			getStatistics( area,mean);
			Back[i]=mean;
			roiManager("Select", 2);
			setSlice (num);
			getStatistics (area, mean);
			Ref[i]=mean;
			roiManager("Select", 1);
			setSlice (num);
			getStatistics (area, mean);
			Frap[i]=mean;
				}


/*----------------------------------------graph raws datas--------------------------------------------------- */
		BackMean = 0;
		for (i = 0; i != nbSliceStack; i++)
			BackMean += Back[i];
		BackMean = BackMean / nbSliceStack;				//background mean

		Plot.create    ("Raw Datas", "Temps sec", "MeanIntensity");
		Plot.setLimits (0, imageTime[imageTime.length-1], BackMean / 1.02, Frap[0] * 1.02);
		Plot.setColor  ("black");
		Plot.add       ("line", imageTime, Back);
		Plot.add       ("circle", imageTime, Back);

		Plot.setColor  ("green");
		Plot.add       ("line", imageTime, Ref);
		Plot.add       ("circle", imageTime, Ref);
		
		
		Plot.setColor  ("blue");
		Plot.add       ("line", imageTime, Frap);
		Plot.add       ("circle", imageTime, Frap);
		
		Plot.show();

/*----------------------------------------soustraction bakground et normalisation--------------------------------------------------- */

// Soustraction du background

			BackMean = 0;
		for (i = 0; i != nbSliceStack; i++)
			BackMean += Back[i];
		BackMean = BackMean / nbSliceStack;				//background mean
		
		FrapCorrBack   = newArray(nbSliceStack);
		RefCorrBack   = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
		{
			FrapCorrBack[i] = Frap[i] - BackMean;
			RefCorrBack [i] = Ref [i] - BackMean;			// soustraction BackMean
		}

	// Find the image num of the FRAP Event
	
	frapIndex = 0;
	selectWindow(SequenceName);
	setSlice(1);
	getStatistics(area, meanMin);
	for (i = 2; i != nbSliceStack; i++)
	{
		setSlice(i + 1);
		getStatistics(area, mean);
		if(mean < meanMin)
		{
			meanMin		= mean;
			frapIndex	= i;
		}
	}
	setSlice(1);
	frapIndex++;
	xFrap=frapIndex;
	print (xFrap);

// normalisation à 1

		// ****** Premiere normalisation (Normalisation a 1 de Frap et Ref)
		SumPBFrap = 0;
		for (i = 1; i != xFrap - 1; i++)
			SumPBFrap += FrapCorrBack[i];											// determination de maxFrap, valeur utilisee pour normaliser la courbe de FRAP a 1
		maxFrap = SumPBFrap / (xFrap - 2);										// maxFrap est la moyenne des intensites prebleach a l'exclusion de la 1ere (cause effet dark state)

		SumPBRef = 0;
		for(i = 1; i != xFrap - 1; i++)
			SumPBRef += RefCorrBack[i];											// determination de maxRef, valeur utilisee pour normaliser la courbe de FRAP a 1
		maxRef = SumPBRef / (xFrap - 2);										// maxRef est la moyenne des intensites prebleach a l'exclusion de la 1ere (cause effet dark state)

		NormFrap = newArray(nbSliceStack);
		NormRef  = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
		{
			NormFrap[i] = (FrapCorrBack[i] / maxFrap);
			NormRef [i] = (RefCorrBack [i] / maxRef);
		}


	// ****** Seconde Normalisation (Normalisation de Frap par Ref)
		Norm2Frap = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
			Norm2Frap[i] = NormFrap[i] / NormRef[i];


		Plot.create    ("Data CorrNorm", "Temps sec", "MeanIntensity");
		Plot.setLimits (0, imageTime[imageTime.length-1], 0, Norm2Frap[0] * 1.1);
		
		Plot.setColor  ("green");
		Plot.add       ("line", imageTime, NormRef);
		Plot.add       ("circle", imageTime, NormRef);

		Plot.setColor  ("blue");
		Plot.add       ("line", imageTime, NormFrap);
		Plot.add       ("circle", imageTime, NormFrap);
		
		Plot.setColor  ("red");
		Plot.add       ("line", imageTime, Norm2Frap);
		Plot.add       ("circle", imageTime, Norm2Frap);
		
		Plot.show();

}

/* -----------------------------------------------------------------------------------------------------------------*/
/*                                                  Analyse du FRAP                                             */
/* ----------------------------------------------------------------------------------------- -----------------------*/

/*	Dialog.create("DataSet for fitting");
	items = newArray("Red _withRefCorr", "Blue_nonRefCorr");
	Dialog.addRadioButtonGroup("DataSet for fitting", items, 1, 1, "Red _withRefCorr");
	Dialog.show();
	choix = Dialog.getRadioButton();
	test =  matches (choix,"Blue_nonRefCorr") ;
	NFrap=newArray (nbSliceStack);																	// la table qui contient les datas à fitter		
	if (test ==1){
	 		for(i = 0; i != nbSliceStack; i++) NFrap[i] = NormFrap[i];									//si on ne veux pas corriger du bleaching  
	 		}
	 		else {
	 		for(i = 0; i != nbSliceStack; i++) NFrap[i] = Norm2Frap[i];									//si on veut corriger du bleaching
	 		}


		//****** Selection de la portion de courbe à considéerer pour le fit 
		RecimageTime = newArray(nbSliceStack - xFrap + 1);							//t0 pour le point xFrap 
		RecFrap      = newArray(nbSliceStack - xFrap + 1);							
		for (i = 0; i != nbSliceStack - xFrap + 1; i++)
		{
			RecimageTime[i] = imageTime[i + xFrap - 1] - imageTime[xFrap - 1];
			RecFrap     [i] = NFrap   [i + xFrap - 1];
		}

		 	
		//****** fit de la courbe de recouvrement
		FitFrap = newArray (RecFrap.length); 
		
		Fit.doFit("y = a * (1 - exp(-x * b)) + c* (1 - exp(-x * d)) + e", RecimageTime, RecFrap);	
		for (i = 0; i != RecFrap.length; i++)
			FitFrap[i] = Fit.f(RecimageTime[i]);
		A1   =     Fit.p(0);
		Tau1 = 1 / Fit.p(1);
		A2 	=  	 Fit.p(2);
		Tau2 = 1 / Fit.p(3);
		Yo  =     Fit.p(4);
		R2  =  Fit.rSquared;

		

		//****** Equation de la courbe
		//tdemi      = Tau*(log(2));
		min       = FitFrap[0];
		dynamique = 1 - min;
		max       = FitFrap[FitFrap.length - 1];							// max=a*(1-exp(-10000000/b))+c; //(10000000 etant suppose etre l'infini)
		mobile    = 100 * (max - min) / dynamique;
		dynamique = (1 - min) * 100;										// conversion en %
		poidsTau1=100*A1/(A1+A2);
		poidsTau2=100*A2/(A1+A2);
		
			
		

	//****** Graph du fit
	

		Plot.create    ("Fit", "Temps", "Intensite", RecimageTime, FitFrap);
		Plot.setLimits (0, RecimageTime[RecimageTime.length - 1], NFrap[xFrap - 1] * 0.75, 1.1);
		Plot.setColor  ("black"); 
		Plot.setColor  ("red"); 
		Plot.add       ("circles", RecimageTime, RecFrap); 
		Plot.setColor  ("blue");	
		Plot.show();
		FigName=ParentPath+ "\\" + SequenceName + "FitPlot";
		saveAs("jpeg", FigName);
		


/* -----------------------------------------------------------------------------------------------------------------*/
/*                                     creation du fichier résultats                                        *    /

/* -----------------------------------------------------------------------------------------------------------------*/
/*	print("\\Clear") ;		

		print ("ImageSerie:",SequenceName);
		print ("fit DoubleExponential+Offset");
		print ("efficacité FRAP =",dynamique);												//paramètres issu du fit
		print ("Mobile Fraction =",mobile);
		print ("Tau1=", Tau1);
		print ("%Tau1=", poidsTau1);
		print ("Tau2=",Tau2);
		print ("%Tau2=", poidsTau2);
		print ("fit  goodness, R2 score=",R2); 
	
	print ("Time(sec) ", "DataNorm", "Fit");   // creat a txt file with the  datas 
	for (i = 0; i != RecFrap.length; i++)
	print(RecimageTime[i], RecFrap [i],FitFrap[i]);
	
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_ResultDatas.txt";
	saveAs("Text", resName);*/

//}



macro "Analyse FRAPdoubleExpo [2]"{


roiManager("Sort");																					//pour que les ROI soient toujours dans le m^me ordre car appelées ensuite selon leur index
	
/* -----------------------------------------------------------------------------------------------------------------*/
/*                                                  plot Raw datas                                                */
/* ----------------------------------------------------------------------------------------- -----------------------*/

		selectWindow(SequenceName);
		Back = newArray(nSlices);
		Ref  = newArray(nSlices);
		Frap = newArray(nSlices);

/* création des tables de mesures des intensités dans les ROIs*/		
			for (i = 0; i != nSlices; i++)
				{ 
			num=i+1;
			roiManager("Select", 0);
			setSlice (num);
			getStatistics( area,mean);
			Back[i]=mean;
			roiManager("Select", 2);
			setSlice (num);
			getStatistics (area, mean);
			Ref[i]=mean;
			roiManager("Select", 1);
			setSlice (num);
			getStatistics (area, mean);
			Frap[i]=mean;
				}


/*----------------------------------------graph raws datas--------------------------------------------------- */
		

		Plot.create    ("Raw Datas", "Temps sec", "MeanIntensity");
		Plot.setLimits (0, imageTime[imageTime.length-1], BackMean / 1.02, Frap[0] * 1.02);
		Plot.setColor  ("black");
		Plot.add       ("line", imageTime, Back);
		Plot.add       ("circle", imageTime, Back);

		Plot.setColor  ("green");
		Plot.add       ("line", imageTime, Ref);
		Plot.add       ("circle", imageTime, Ref);
		
		
		Plot.setColor  ("red");
		Plot.add       ("line", imageTime, Frap);
		Plot.add       ("circle", imageTime, Frap);
		
		Plot.show();



/*----------------------------------------file.txt raws datas--------------------------------------------------- */

	print("\\Clear") ;		
	//for(i = 2; i < =nbSliceStack; i++)	
	//	print (imageTime[i-1]);  /*recup des valeurs de temps pour chaque image - t0*/
	
	print ("Time(sec) ", "Background", "Bleaching" , "FRAP");   // creat a txt file with the mean intensity datas 
	for (i = 0; i != nbSliceStack; i++)
	print(imageTime[i], Back[i],Ref[i],Frap[i]);
	
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_RawDatas.txt";
	saveAs("Text", resName);


/*----------------------------------------soustraction bakground et normalisation--------------------------------------------------- */

// Soustraction du background
		
		FrapCorrBack   = newArray(nbSliceStack);
		RefCorrBack   = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
		{
			FrapCorrBack[i] = Frap[i] - BackMean;
			RefCorrBack [i] = Ref [i] - BackMean;			// soustraction BackMean
		}

	// Find the image num of the FRAP Event
	
	frapIndex = 0;
	selectWindow(SequenceName);
	setSlice(1);
	getStatistics(area, meanMin);
	for (i = 2; i != nbSliceStack; i++)
	{
		setSlice(i + 1);
		getStatistics(area, mean);
		if(mean < meanMin)
		{
			meanMin		= mean;
			frapIndex	= i;
		}
	}
	setSlice(1);
	frapIndex++;
	xFrap=frapIndex;
	print (xFrap);

// normalisation à 1

		// ****** Premiere normalisation (Normalisation a 1 de Frap et Ref)
		SumPBFrap = 0;
		for (i = 1; i != xFrap - 1; i++)
			SumPBFrap += FrapCorrBack[i];											// determination de maxFrap, valeur utilisee pour normaliser la courbe de FRAP a 1
		maxFrap = SumPBFrap / (xFrap - 2);										// maxFrap est la moyenne des intensites prebleach a l'exclusion de la 1ere (cause effet dark state)

		SumPBRef = 0;
		for(i = 1; i != xFrap - 1; i++)
			SumPBRef += RefCorrBack[i];											// determination de maxRef, valeur utilisee pour normaliser la courbe de FRAP a 1
		maxRef = SumPBRef / (xFrap - 2);										// maxRef est la moyenne des intensites prebleach a l'exclusion de la 1ere (cause effet dark state)

		NormFrap = newArray(nbSliceStack);
		NormRef  = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
		{
			NormFrap[i] = (FrapCorrBack[i] / maxFrap);
			NormRef [i] = (RefCorrBack [i] / maxRef);
		}


	// ****** Seconde Normalisation (Normalisation de Frap par Ref)
		Norm2Frap = newArray(nbSliceStack);
		for(i = 0; i != nbSliceStack; i++)
			Norm2Frap[i] = NormFrap[i] / NormRef[i];


		Plot.create    ("Data CorrNorm", "Temps sec", "MeanIntensity");
		Plot.setLimits (0, imageTime[imageTime.length-1], 0, Norm2Frap[0] * 1.1);
		
		Plot.setColor  ("green");
		Plot.add       ("line", imageTime, NormRef);
		Plot.add       ("circle", imageTime, NormRef);

		Plot.setColor  ("blue");
		Plot.add       ("line", imageTime, NormFrap);
		Plot.add       ("circle", imageTime, NormFrap);
		
		Plot.setColor  ("red");
		Plot.add       ("line", imageTime, Norm2Frap);
		Plot.add       ("circle", imageTime, Norm2Frap);
		
		Plot.show();

/* -----------------------------------------------------------------------------------------------------------------*/
/*                                                  Analyse du FRAP                                             */
/* ----------------------------------------------------------------------------------------- -----------------------*/

	Dialog.create("DataSet for fitting");
	items = newArray("Red _withRefCorr", "Blue_nonRefCorr");
	Dialog.addRadioButtonGroup("DataSet for fitting", items, 1, 1, "Red _withRefCorr");
	Dialog.show();
	choix = Dialog.getRadioButton();
	test =  matches (choix,"Blue_nonRefCorr") ;
	NFrap=newArray (nbSliceStack);																	// la table qui contient les datas à fitter		
	if (test ==1){
	 		for(i = 0; i != nbSliceStack; i++) NFrap[i] = NormFrap[i];									//si on ne veux pas corriger du bleaching  
	 		}
	 		else {
	 		for(i = 0; i != nbSliceStack; i++) NFrap[i] = Norm2Frap[i];									//si on veut corriger du bleaching
	 		}


		//****** Selection de la portion de courbe à considéerer pour le fit 
		RecimageTime = newArray(nbSliceStack - xFrap + 1);							//t0 = pour le point xFrap 
		RecFrap      = newArray(nbSliceStack - xFrap + 1);							
		for (i = 0; i != nbSliceStack - xFrap + 1; i++)
		{
			RecimageTime[i] = imageTime[i + xFrap - 1] - imageTime[xFrap - 1];
			RecFrap     [i] = NFrap   [i + xFrap - 1];
		}

		//********Fit sur toute la courbe ou selection d'une plage (limite en temps) 			
		Dialog.create("End Time for fitting?");
		Dialog.addString("Stop ", "WholeTime", 20);
		Dialog.show();
		SelectEndTime=Dialog.getString();	
		test =  matches (SelectEndTime,"WholeTime") ;							//tfin si on ne veut pas considerer la totalité de points
		if (test ==1){
	 		FrapLength= RecFrap.length; 								 
	 		}
	 		else {
			endTime=parseInt( SelectEndTime);
			i=0;
			do{
					FrapLength=i;
					i=i+1;
				}  while( RecimageTime[i]<endTime);						
	 		}
	 		
		FitFrap = newArray (FrapLength); 	

				 	
		//****** fit de la courbe de recouvrement 
		FitFrap = newArray (FrapLength); 

		XFrapToFit = newArray(FrapLength);							//t0 pour le point xFrap 
		YFrapToFit = newArray(FrapLength);							
		for (i = 0; i != FrapLength; i++)
		{
			XFrapToFit[i] = RecimageTime[i];
			YFrapToFit[i] = RecFrap[i];
		}
		
		Fit.doFit("y = a * (1 - exp(-x * b)) + c* (1 - exp(-x * d)) + e", XFrapToFit, YFrapToFit);	
		for (i = 0; i != FrapLength; i++)
			FitFrap[i] = Fit.f(XFrapToFit[i]);
		A1   =     Fit.p(0);
		Tau1 = 1 / Fit.p(1);
		A2 	=  	 Fit.p(2);
		Tau2 = 1 / Fit.p(3);
		Yo  =     Fit.p(4);
		R2  =  Fit.rSquared;

		

		//****** Equation de la courbe

		min       = FitFrap[0];
		dynamique = 1 - min;
		max       = FitFrap[FrapLength - 1];							
		mobile    = 100 * (max - min) / dynamique;
		dynamique = (1 - min) * 100;										// conversion en %
		poidsTau1=100*A1/(A1+A2);
		poidsTau2=100*A2/(A1+A2);
	
	//****** Graph du fit


		Plot.create    ("Fit", "Temps", "Intensite", XFrapToFit, FitFrap);
		Plot.setLimits (0, XFrapToFit[FrapLength - 1]*0.95, NFrap[xFrap - 1] * 0.75, 1.1);
		Plot.setColor  ("black"); 
		Plot.setColor  ("red"); 
		Plot.add       ("circles", XFrapToFit, YFrapToFit); 
		Plot.setColor  ("blue");	
		Plot.show();
		FigName=ParentPath+ "\\" + SequenceName + "FitPlot";
		saveAs("jpeg", FigName);
		


/* -----------------------------------------------------------------------------------------------------------------*/
/*                                     creation des fichiesr résultats                                        *    /

/* -----------------------------------------------------------------------------------------------------------------*/


//------------------------file.txt raws datas

	print("\\Clear") ;		
	//for(i = 2; i < =nbSliceStack; i++)	
	//	print (imageTime[i-1]);  /*recup des valeurs de temps pour chaque image - t0*/
	
	print ("Time(sec) ", "Background", "Reference" , "FRAP");   // creat a txt file with the mean intensity datas 
	for (i = 0; i != nbSliceStack; i++)
	print(imageTime[i], Back[i],Ref[i],Frap[i]);
	
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_RawDatas.txt";
	saveAs("Text", resName);



//------------------------file.txt norm et fit datas


	print("\\Clear") ;		

	
	print ("Time(sec) ", "DataNorm", "Fit");   // creat a txt file with the  datas 
	for (i = 0; i != RecFrap.length; i++)
	print(RecimageTime[i], RecFrap [i]);
			
	print("Fit curve: ");
		
		print ("Time(sec) ", "Fit");   // creat a txt file with the  datas 
	for (i = 0; i != FrapLength; i++)
	print(RecimageTime[i],FitFrap[i]);
	
 print("Param from fit analysis: ");
		
		print ("ImageSerie:",SequenceName);
		print ("fit DoubleExponential+Offset");
		print ("efficacité FRAP =",dynamique);												//paramètres issu du fit
		print ("Mobile Fraction =",mobile);
		print ("Tau1=", Tau1);
		print ("%Tau1=", poidsTau1);
		print ("Tau2=",Tau2);
		print ("%Tau2=", poidsTau2);
		print ("fit  goodness, R2 score=",R2); 
	
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_ResultDatas.txt";
	saveAs("Text", resName);


}

/* -----------------------------------------------------------------------------------------------------------------*/
/*                                               fonctions                                                         */
/* ----------------------------------------------------------------------------------------- -----------------------*/

/* get Real Time in a Metamorph TimeLapse (2D image) */
	
	
function getImageTime()
	{
		info		= getMetadata("Info");
		infolist	= split(info, "\t\n\r");
		for (i = 0; i < infolist.length; i++)
		{

			if(startsWith(infolist[i], "<prop id=\"acquisition-time-local\" type=\"time\""))
			{
//			print(infolist[i]);
				time_in_string	= substring(infolist[i], 62, lengthOf(infolist[i]) - 3);
				time_in_array	= split(time_in_string, ":");
				time_in_sec		= 3600 * time_in_array[0] + 60 * time_in_array[1] + time_in_array[2];
				//print (time_in_sec);
				return time_in_sec;
			}
		}
		return 0;
	}

/* ----------------------------------------------------------------------------------------- -----------------------*/
		
/* Create ROI in the ROI manager from the Openstring of the .rgn Metamorph  */

function createROI(str2, index)
	{
		roi				= split(str2   , ",");
		roiData 		= split(roi[6] , " ");

		// Fill the ROI x - y coordinates definitions within an array
		x_coordinates	= newArray(roiData[4]);
		y_coordinates	= newArray(roiData[5]);
		for(i = 6; i != roiData.length; i = i + 2)
		{
			x_coordinates = Array.concat(x_coordinates, roiData[i    ]);
			y_coordinates = Array.concat(y_coordinates, roiData[i + 1]);
		}

		// Needed to get rid of the spikes within the ROI definition
		x_coordinates	= deleteArrayElement(x_coordinates, 24);
		y_coordinates 	= deleteArrayElement(y_coordinates, 24);
		x_coordinates	= deleteArrayElement(x_coordinates, 16);
		y_coordinates 	= deleteArrayElement(y_coordinates, 16);
		x_coordinates	= deleteArrayElement(x_coordinates,  8);
		y_coordinates 	= deleteArrayElement(y_coordinates,  8);
		x_coordinates	= deleteArrayElement(x_coordinates,  0);
		y_coordinates 	= deleteArrayElement(y_coordinates,  0);

		makeSelection("polyline", x_coordinates, y_coordinates);
//		Roi.setStrokeWidth(1);
		Roi.setName("ROI_" + index);
		roiManager ("Add");

//		return index;
	}


	function deleteArrayElement(array, index)
	{
		return Array.concat(Array.slice(array, 0, index - 1), Array.slice(array, index + 1, array.length));
	}

   /* ----------------------------------------------------------------------------------------- -----------------------*/