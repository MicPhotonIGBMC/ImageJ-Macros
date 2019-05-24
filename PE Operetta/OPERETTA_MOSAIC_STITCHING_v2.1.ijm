/*
MACRO FOR OPERETTA v2.1 (22022017)

AUTHORS: Joan Casamitjana*, Bertrand Vernay and Isaac Shaw
*Main coder, any doubt contact Joan (s1478844@sms.ed.ac.uk).

Aims: This macro will generate a reconstruction of your Operetta scan as viewed in Columbus when all fields are selected, but with full resolution.

This macro only works with single channel images and a maximum of 4 channels (downloaded folder from Columbus when you back up your data). 

This macro automatically detects number of files, channels, reset max intensity (as fiji is applying autocontrast), merges single images, calculates their relative position, stitches them, treats single channels (as an option) and saves it as a tif file.
By default, this macro treats the single channels of your montage by Substract background and setting B/C in Auto, in that order. 
If other treatments are required, user will have to change treatments settings on the script. 
*/

macro "Operetta Stitching [F1]" { //installs this macro with F1 botton as a shortcut -- has to be done manually
 	
//set batch mode to true for faster processing
setBatchMode(true); 

//DIALOG BOX - WARNING
Dialog.create("WARNING");
Dialog.addMessage("1- To run this macro properly, all windows will be closed and clipboard content will be erased. Pressing OK will close them without option to save them."+'\n'+ "2- Stiching in FIJI does not like long directory names. It is recommended to copy the final folder on your desktop for the execution of this makro.");
Dialog.show();

//Clear log window
print("\\Clear");

//Start message
print("------ MACRO STARTED ------");

//Input & output directories
folder = getDirectory("Select the folder containing your raw files");

//Variables initialisation
var count=0;
var xCoordinate = newArray(1);		//one indexed value of 0
var newxCoordinate = newArray(1);	//one indexed value of 0
var newyCoordinate = newArray(1);	//one indexed value of 0
var ycoordinate = newArray(1);		//one indexed value of 0
var newX = newArray(1);	//one indexed value of 0
var tileName = newArray("tile");	//one indexed string of "tile"
var tileInX =1;
var tileInY=1;
var xInterval = 1;
var yInterval = 1;
var minX=0;
var manX=0;
var minY=0;
var maxY=0;
var num_single_images=0

//Main body of macro
//selects the beginning of your files (assuming it is always something like '001002-')
listFiles(folder); 
function listFiles(folder) {
	list1 = getFileList(folder);
	for (i=0; i<1; i++) { //picks up the first file only
		beginning_of_your_file = substring(list1[i],0,7); //takes first 7 characters of the file name
		String.copy(beginning_of_your_file); //copies the string into the clipboard
	}
}
beginning_of_your_file = String.paste //generates the object with the content of the clipboard, THIS HAS TO GO WITH THE PREVIOUS!!!

//Counting number of total single images (we still inside the previous function)	
listFiles2(folder); 
function listFiles2(folder) {
	list2 = getFileList(folder);
	for (i=0; i<list2.length; i++){
		tifs=indexOf(list2[i], ".tif"); //look for all tif files and counts them
		if (tifs != -1) {	
			num_single_images++;
		}
	}
}

//DIALOG BOX - INPUT VALUES (external information that user need to introduce manually)
Dialog.create("Introducing parameters");
Dialog.addNumber("Percentage of overlap", 10);
//Dialog.addChoice("Objective used:", newArray("2x", "10x", "20x", "40x", "60x", "100x"));
//Dialog.addNumber("Scale bar in microns", 100);
Dialog.addString("Save your final image as (.tif)", "Montage");
Dialog.addCheckbox("Delete Composite folder", true);
Dialog.addCheckbox("Delete Tile folder", true);
Dialog.addCheckbox("Enhance image (modify the pixel data)", false);
Dialog.show();
overlap = Dialog.getNumber();
//objective_used = Dialog.getChoice();
//dim_scalebar = Dialog.getNumber();
montage_name = Dialog.getString();
del_CompositeFolder = Dialog.getCheckbox();
del_TileFolder = Dialog.getCheckbox();
enhance = Dialog.getCheckbox(); 

run("Close All");
print("\\Clear"); //Reset log
print("The working folder path is: " + folder);
print("Your files begin with '" + beginning_of_your_file + "'");
//print("Your montage will be displayed at " + (montage_scale*100) + "% of its total resolution.");
//print("Objective used: " + objective_used);
//print("Scale bar displayed: " + dim_scalebar + "um");
print("Your montage will be saved as: " + montage_name + ".tif");

field_heigth = 1024 //in pixels. Dimension of your images. Required for blank images.
field_width = 1360 //in pixels
startingTime = getTime(); 

//find metadata *.xml file and extract coordinates and number of tiles
list = getFileList(folder);
	for (m=0; m<list.length; m++){
		print(list[m]);
		if (endsWith(list[m], "xml")) {
			//Open metadata file as a string
	filestring=File.openAsString(folder+list[m]);
	delimiters='(<URL BufferNo="0">)';		//create line return after <URL BufferNo="0">
	rows=split(filestring, delimiters);		//create line return after <URL BufferNo="0">

	//Counting number of tiles listed in metadata: based on first channel (there is always a channel1)
	for (i=0; i<rows.length; i++){
		indexTileNameTif=indexOf(rows[i], ".tif");			//Check if line contains ".tif"
		row_channel1=indexOf(rows[i], "1.tif");					//Check if line contains "1.tif"
			if ((indexTileNameTif != -1) && (row_channel1 != -1)) {	 //selecting only first channel for each tile
				count++;
				}
		}			
	print("Number of tiles= "+count);

	//Extraction X and Y coordinates for each tile
	for (i=0; i<rows.length; i++){
		indexTileNameTif=indexOf(rows[i], ".tif");			//Check if line contains ".tif"
		row_channel1=indexOf(rows[i], "1.tif");			
			if ((indexTileNameTif != -1) && (row_channel1 != -1)) {			//Conditions only process line containig both ".tif" & "1.tif"	
				name =substring(rows[i], 0, indexTileNameTif+4);	//Extract tile file name from metadata
				//print("Tile name= "+name);
				xPositionStart= (indexOf(rows[i], '<PositionX Unit="m">'));
				xPositionStop= (indexOf(rows[i],'</PositionX>'));
				yPositionStart= (indexOf(rows[i], '<PositionY Unit="m">'));
				yPositionStop= (indexOf(rows[i],'</PositionY>'));
				TileXPosition= substring(rows[i],xPositionStart+20,xPositionStop);  //Get TileXPosition position coordinates		
				TileXPosition= 100000000000000*parseFloat(TileXPosition);					//TileXPosition in float, it is multiplied by 10^14 since operetta gives 14 decimal numbers
				TileYPosition= substring(rows[i],yPositionStart+20,yPositionStop);	//Get TileYPosition position coordinates	
				TileYPosition= 100000000000000*parseFloat(TileYPosition);					//TileYPosition in float
				TileXPosition= parseInt(TileXPosition);								//TileXPosition as integer
				TileYPosition= parseInt(TileYPosition);								//TileYPosition as integer
				//print(TileXPosition);
				//print(TileYPosition);
				tileName = Array.concat(tileName, name);	
				xCoordinate = Array.concat(xCoordinate, TileXPosition);				//add x coordinate to array
  				yCoordinate = Array.concat(yCoordinate, TileYPosition);				//add y coordinate to array
				//print("X coordinates");
				//Array.print(xCoordinate);
				//print("Y coordinates");
				//Array.print(yCoordinate);
				}
		}

		//Final list of X & Y coordinates and name for tiles
		print("***********************************************");
		//print("X coordinates");
		xCoordinate = Array.slice(xCoordinate,1);				//remove first value created at initialisation of array
		//Array.print(xCoordinate);				
		for (h=0;h<xCoordinate.length; h++){
		//print(xCoordinate[h]);
		}
		//print("Y coordinates"); 
		yCoordinate = Array.slice(yCoordinate,1);				//remove first value created at initialisation of array
		//Array.print(yCoordinate);
		for (h=0;h<yCoordinate.length; h++){
		//print(yCoordinate[h]);
		}

	//Determining mosaic size in width and height
	xStats=Array.getStatistics(xCoordinate, min, max, mean, stdDev);		//min and max value of x coordinates
	minX = min;
	print("min X= "+minX);
	maxX = max;
	print("max X= "+maxX);

	yStats = Array.getStatistics(yCoordinate, min, max, mean, stdDev);		//min and max value of y coordinates
	minY = min;
	print("min Y= "+minY);
	maxY= max;
	print("max Y= "+maxY);

//Getting the tile interval
	superArrayX= Array.copy(xCoordinate);
	superArrayX= Array.sort(superArrayX);
	for (i=0; i+1<superArrayX.length; i++){
		x1num =(superArrayX[i]);
		x2num = (superArrayX[i+1]);
		if (x1num != x2num){
			xInterval = x2num -x1num;
			//print("Tile X Interval = "+xInterval);
		}
	}
	superArrayY= Array.copy(yCoordinate);
	superArrayY= Array.sort(superArrayY);
	for (i=0; i+1<superArrayY.length; i++){
		y1num =(superArrayY[i]);
		y2num = (superArrayY[i+1]);
		if (y1num != y2num){
			yInterval = y2num -y1num;
			//print("Tile Y Interval = "+yInterval);
		}
	}

//Obtaining coordinates (simple numbers)
	for (h=0; h<xCoordinate.length; h++){
		newX = xCoordinate[h];
		newX = round((newX-minX)/xInterval);
		newxCoordinate = Array.concat(newxCoordinate, newX);	
		}
	newxCoordinate = Array.slice(newxCoordinate,1);

	for (h=0; h<yCoordinate.length; h++){
		newY = yCoordinate[h];
		newY= abs(round((newY-maxY)/yInterval)); //y numbers are negative, we need them positive
		//print(newY);
		newyCoordinate = Array.concat(newyCoordinate, newY);
		}
	newyCoordinate = Array.slice(newyCoordinate,1);
	
//resuming the size
	tileInX=parseInt((maxX-minX)/xInterval)+1;	// add 1 to make it works WHY?
	print(tileInX +" tiles in X");

	tileInY=parseInt((maxY-minY)/yInterval)+1;	// add 1 to make it works WHY?
	print(tileInY +" tiles in Y");
			}
	}

print("You are processing " + count + " fields.");

//Calculating number of channels
number_of_channels = num_single_images/count
print("You are processing " + number_of_channels + " channels.");

//Creating output folder: Composites
Composites = folder+"Composites"+File.separator;
File.makeDirectory(Composites);
CompositeFolder = folder+ "Composites\\"
print("Generated files can be located in: " + CompositeFolder);

for (i = 1; i < count+1 ; i++) {
	//1 CHANNEL
	if (number_of_channels == 1) {
		open(folder + beginning_of_your_file + i + "-001001001.tif");
		n1= beginning_of_your_file + i + "-001001001.tif";
		selectWindow(n1);
		setMinAndMax(0, 16384);
		}
	//2 CHANNELS
	if (number_of_channels == 2) {
		open(folder + beginning_of_your_file + i + "-001001001.tif");
		n1= beginning_of_your_file + i + "-001001001.tif";
		selectWindow(n1);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001002.tif");
		n2= beginning_of_your_file + i + "-001001002.tif";
		selectWindow(n2);
		setMinAndMax(0, 16384);
		run("Merge Channels...", "c2=" + n2 + " c3=" + n1 + " create");
		}
	//3 CHANNELS
	if (number_of_channels == 3) {
		open(folder + beginning_of_your_file + i + "-001001001.tif");
		n1= beginning_of_your_file + i + "-001001001.tif";
		selectWindow(n1);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001002.tif");
		n2= beginning_of_your_file + i + "-001001002.tif";
		selectWindow(n2);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001003.tif");
		n3= beginning_of_your_file + i + "-001001003.tif";
		selectWindow(n3);
		setMinAndMax(0, 16384);
		run("Merge Channels...", "c1=" + n3 + " c2=" + n2 + " c3=" + n1 + " create");
		}
	//4 CHANNELS
	if (number_of_channels == 4) {
		open(folder + beginning_of_your_file + i + "-001001001.tif");
		n1= beginning_of_your_file + i + "-001001001.tif";
		selectWindow(n1);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001002.tif");
		n2= beginning_of_your_file + i + "-001001002.tif";
		selectWindow(n2);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001003.tif");
		n3= beginning_of_your_file + i + "-001001003.tif";
		selectWindow(n3);
		setMinAndMax(0, 16384);
		open(folder + beginning_of_your_file + i + "-001001004.tif");
		n4= beginning_of_your_file + i + "-001001004.tif";
		selectWindow(n4);
		setMinAndMax(0, 16384);
		run("Merge Channels...", "c1=" + n3 + " c2=" + n2 + " c3=" + n1 + " c4=" + n4 + " create"); 
		}

saveAs("Tiff", CompositeFolder + "Field " + i);
print("Field " + i + " processed...");
close();
}

//Creating a blank image to fill empty spaces
newImage("Field b", "16-bit black", field_width, field_heigth, 1);
if (number_of_channels == 2) {
	run("Merge Channels...", "c2=[Field b] c3=[Field b] create"); //if you have more than one channel, add cx=[Field b] per channel. The channel selected should be the same as your initial image
	}
if (number_of_channels == 3) {
	run("Merge Channels...", "c1=[Field b] c2=[Field b] c3=[Field b] create"); //if you have more than one channel, add cx=[Field b] per channel. The channel selected should be the same as your initial image
	}
if (number_of_channels == 4) {
	run("Merge Channels...", "c1=[Field b] c2=[Field b] c3=[Field b] c4=[Field b] create"); //if you have more than one channel, add cx=[Field b] per channel. The channel selected should be the same as your initial image
	}
saveAs("Tiff", CompositeFolder + "Field b"); 
print("Blank field generated...");
close();

//Creating the tile folder and adding the images. First full y*x grid, then real images will be copied on top of those, a full grid with blank images and actual images.
Tiles = folder+"Tiles"+File.separator;
File.makeDirectory(Tiles);
TileFolder = folder+ "Tiles\\";

var Xarray = newArray(1);
var Yarray = newArray(1);
var blankXarray = newArray(1);
var blankYarray = newArray(1);
var blankArray = newArray(1);

//blank X and Y array
Xarray = Array.getSequence(tileInX);
for (i=0; i<tileInY; i++){
	blankXarray = Array.concat(blankXarray,Xarray);
}
blankXarray = Array.slice(blankXarray,1,(tileInX*tileInY)+1); //previous loops generates a first array with one value "0" as the first blank array does not actually exists.

Yarray = Array.getSequence(tileInY);
for (i=0; i<tileInY+1; i++){
	blankYarray = Array.concat(blankYarray,Yarray);
}
blankYarray = Array.slice(blankYarray,1,(tileInX*tileInY)+1);
blankYarray = Array.sort(blankYarray);

//renaming the tile files. First total blank images, then actual images
print("Generating blank tiles copies ...");
for (n=0; n<(tileInX*tileInY); n++){
	File.copy(CompositeFolder+"Field b.tif", TileFolder+"Field_x"+blankXarray[n]+"_y"+blankYarray[n]+".tif");
	//print(TileFolder+"Field_x"+blankXarray[n]+"_y"+blankYarray[n]+".tif");
}
print("Blank tiles copies generated...");
print("Renaming and replacing real images in Tile folder...");
for (h=0; h<count; h++){
	File.copy(CompositeFolder+"Field "+ (h+1) +".tif", TileFolder+"Field_x"+newxCoordinate[h]+"_y"+newyCoordinate[h]+".tif");
}
print("Real images in Tile folder...");


//Stiching & renaming your image
print("Stiching...");
run("Grid/Collection stitching", "type=[Filename defined position] order=[Defined by filename         ] grid_size_x="+tileInX+" grid_size_y="+tileInY+" tile_overlap="+overlap+" first_file_index_x=0 first_file_index_y=0 directory="+TileFolder+ " file_names=Field_x{x}_y{y}.tif output_textfile_name=TileConfiguration.txt fusion_method=[Max. Intensity] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");
print("Stiching completed...");
selectWindow("Fused");
run("Scale...", "x=1 y=1 interpolation=Bilinear average create title=Montage");
selectWindow("Fused");
close();

if (enhance == true)
	{
		autoContrast();
	}

//saving your montage
Montages = folder+"Montages"+File.separator;
File.makeDirectory(Montages);
MontageFolder = folder+ "Montages\\";

saveAs("Tiff", MontageFolder + montage_name);
run("Close All");

//deleting additonal folder - to make it lighter
if(del_CompositeFolder == true){
	for (i = 1; i < count+1 ; i++) {
		File.delete(CompositeFolder+"Field " + i +".tif");
	}
	File.delete(CompositeFolder+"Field b.tif");
	File.delete(CompositeFolder);
	print("Folder containing merged images deleted...");
}
if(del_TileFolder == true){
	for (n=0; n<(tileInX*tileInY); n++){
		File.delete(TileFolder+"Field_x"+blankXarray[n]+"_y"+blankYarray[n]+".tif");
	}
	File.delete(TileFolder+"TileConfiguration.registered.txt");
	File.delete(TileFolder+"TileConfiguration.txt");
	File.delete(TileFolder);
	print("Folder containing tile images deleted...");
}

//farewell messages
print("***********************************************");
print("HUZZAH! Your montage has succesfully been processed and saved!");

time = getTime()-startingTime;
print(time);
mins= time/60000;
mins=floor(mins);
secs=time%60000;
secs=round(secs/1000);
if(mins == 0){
	print("This macro was executed in " +secs+ " seconds.");
}
else {
	print("This macro was executed in " + mins + "minutes and "+secs+ " seconds."); 
}

print("Hope you enjoyed using this macro.");
print("------ MACRO FINISHED ------");

setBatchMode(false);	

/*
OPERETTA CALIBRATIONS
if (objective_used == "2x"){
	run("Set Scale...", "distance=1024 known=5086 pixel=[] unit=um global");
	}
if (objective_used == "10x"){
	run("Set Scale...", "distance=1024 known=1017 pixel=[] unit=um global");
	}
if (objective_used == "20x"){
	run("Set Scale...", "distance=1024 known=509 pixel=[] unit=um global");
	}
if (objective_used == "40x"){
	run("Set Scale...", "distance=1024 known=254 pixel=[] unit=um global");
	}
if (objective_used == "60x"){
	run("Set Scale...", "distance=1024 known=170 pixel=[] unit=um global");
	}
if (objective_used == "100x"){
	run("Set Scale...", "distance=1024 known=102 pixel=[] unit=um global");
	}
*/

//Applying autocontrast - conditional function
function autoContrast(){
	print("Enhancing...");
	selectWindow("Montage");
		//1 CHANNEL
	if (number_of_channels == 2) {
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		}
		//2 CHANNELS 
	if (number_of_channels == 2) {
		run("Split Channels");
		selectWindow("C2-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C1-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		run("Merge Channels...", "c2=C1-Montage c3=C2-Montage create");
		}
		//3 CHANNELS
	if (number_of_channels == 3) {
		run("Split Channels");
		selectWindow("C1-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C2-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C3-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		run("Merge Channels...", "c1=C1-Montage c2=C2-Montage c3=C3-Montage create");
		}
		//4 CHANNELS
	if (number_of_channels == 4) {
		run("Split Channels");
		selectWindow("C1-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C2-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C3-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		selectWindow("C4-Montage");
		run("Subtract Background...", "rolling=50");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		run("Merge Channels...", "c1=C1-Montage c2=C2-Montage c3=C3-Montage c4=C4-Montage create");
		}
	selectWindow("Montage");
	print("Enhacing complete...");
}

}//this one ends the macro function