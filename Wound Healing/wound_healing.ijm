  dir1 = getDirectory("Choose Source Directory "); 								//select input directory
  dir2 = getDirectory("Choose Destination Directory");								//select ouput directory
  list = getFileList(dir1);											//list of file in directory
 setBatchMode(true);    											//use this to save time by not displaying images
	
 for (i=0; i<list.length; i++){											//start of loop to process each file in the input directory
      showProgress(i+1, list.length);
    open(dir1+list[i]);												//open file in input directory					
    run("8-bit");   //my experience is that I get better results in 8-bit.						//convert to 8-bit
    run("Duplicate...", "title=copy duplicate");									//duplicate the file
	selectWindow(list[i]);												//select window corresponding to original file
	run("Sharpen", "stack");  											//run sharpen filter this step really helps a lot for thin cells with thin lamellopodia
	run("Find Edges", "stack");
	setThreshold(0,20);  												//very important to get an appropriate threshold. Threshold can be modifier here
	run("Convert to Mask", " ");											//create a mask out of the thresholded image
	run("Analyze Particles...", "size=12000-Infinity circularity=0.00-1.00 show=Outlines summarize stack");	//analyse the particle (wound), minimal size can be modified here
	selectWindow("Summary of "+list[i]);										//select the result window
	saveAs("Text", dir2+list[i]);											//save the result as a text file
	selectWindow("Drawing of "+list[i]);										//select the duplicate window	
	run("Red");													
	run("Invert LUT");
	run("RGB Color");
	selectWindow("copy");
	run("RGB Color");
	imageCalculator("Add stack", "copy", "Drawing of "+list[i]);
	run("Size...", "width=600 constrain interpolate");
	saveAs("Tiff", dir2+"Drawing "+list[i]);
	close();
	close();
	close();
}
