while (nImages>0) { 
          selectImage(nImages); 
          close(); 
      	} 


	FilePath = File.openDialog("Select a .tif File from the image sequence");					/*recup pathway*/
	ParentPath	= File.getParent(FilePath);								/*recup dossier ou sont les datas */
	FileName	= File.getName  (FilePath);								/* recup nom complet de l'image */
	BaseName	= substring(FileName, 0, lastIndexOf(FileName, "_t"))+"_";    /*recup du nom de base */
	//run("Image Sequence...", "open=FilePath number starting=1 increment=1 scale=100 file=&BaseName sort");	/*charge toute la sequence en temps*/
	SequenceName=substring(FileName, 0, lastIndexOf(FileName, "_t"));  
	//rename(SequenceName);
	//run("Brightness/Contrast...");
	//run("Enhance Contrast", "saturated=0.35");


	print("\\Clear") ;		
	
	setBatchMode(true);
	open(ParentPath + "\\"+ SequenceName + "_t1.tif");
	t0	= getImageTime();
	
	
test=1;
i=1;	
while (test==1)
	{
		i=i+1;
		test=File.exists(ParentPath + "\\"+ SequenceName + "_t" + i + ".tif");
		if (test ==1) open(ParentPath + "\\" + SequenceName + "_t" + i + ".tif");
			} 
	run("Images to Stack", "name=[" + SequenceName + "] title=[] use");
	setBatchMode("exit and display");

 imageTime = newArray(nSlices);		
imageTime[0]	= 0;
	
for(i = 2; i < =nSlices; i++)
	{
		setSlice(i);
		imageTime[i - 1] = getImageTime() - t0;				/*recup des valeurs de temps pour chaque image - t0*/
		//print (imageTime[i-1]);
	}
	print ("RealTime (sec) for ImageSeries ", SequenceName);
	for(i=1;i<=nSlices;i++) print( imageTime[i-1]);
	selectWindow("Log");
	resName=ParentPath+ "\\" + SequenceName+"_RealTime.txt";   // creat a txt file with the time datas
		saveAs("Text", resName);  



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
	