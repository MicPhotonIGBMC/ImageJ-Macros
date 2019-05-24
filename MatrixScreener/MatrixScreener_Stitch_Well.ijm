/* January 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 * F1 to make the hyperstack for each field of view 
 * (change the number of channels/z slices accordingly in line #89 before starting the macro ). 
 * For the output folder select a different folder than the output. 
 * 
 * F2 to stitch the whole well data. Select the previous 
 * output folder containing the hyperstack
 *   
 *  
*/ 

macro "Making stacks [F1]"{
//Initialise macro
print("\\Clear");
setBatchMode(true);
print("***** Macro started *****");
//
var well;
var stitchDir;
//Source and target folders
dir1=getDirectory("Select Screen Folder");		//Folder containing all the wells data i.e. well--U00--V00, well--U00--V01
dir2=getDirectory("Select Save Folder");		//Folder for saving the stacks
listAll = getFileList(dir1);		//list all wells subfolder in dir1
//

//Mapping the well subfolders into an array wellList
print("Listing wells subfolders");
wellList = newArray();
for (n=0; n<listAll.length; n++){
	if (startsWith(listAll[n], "well--")){
	wellList = Array.concat(wellList, listAll[n]);
	}
}
Array.print(wellList);
//

//Processing well folder and the fields 
for (m=0; m<wellList.length; m++){
	wellName=substring(wellList[m], 0,lengthOf(wellList[m])-1);
	print("**********************************");
	print("Processing well= "+wellName);
	fieldList=getFileList(dir1+wellList[m]);
	print("Processing fields:");
	Array.print(fieldList);
	processField(fieldList);
}

//Function for sorting folder and subfolder
function processField(fieldList) {
for (k=0; k<fieldList.length; k++) {
	print("Processing Field= "+dir1+wellList[m]+fieldList[k]);
	fieldPath=dir1+wellList[m]+fieldList[k];
	indexOfX=indexOf(fieldPath, "X");
	indexOfY=indexOf(fieldPath, "Y");
	fieldX=substring(fieldPath, indexOfX,indexOfX+3);
	fieldY=substring(fieldPath, indexOfY,indexOfY+3);	
	intFieldX=parseInt(fieldX);
	intFieldY=parseInt(fieldY);
	processImages(fieldPath);
	}
}

function processImages(fieldPath){
listRename=getFileList(fieldPath);
for(i=0; i<listRename.length; i++){
	pathImage=dir1+wellList[m]+fieldList[k]+listRename[i];
	if (startsWith(listRename[i], "image--")){
		padZero(pathImage); 
	}
}
listImages=getFileList(fieldPath);
for(j=0; j<listImages.length; j++){
	pathToImage=dir1+wellList[m]+fieldList[k]+listImages[j];
	if (startsWith(listImages[j], "image--")){
		open(dir1+wellList[m]+fieldList[k]+listImages[j]);
	}
}	
	makeHyperstack();
	//stitchDir=dir2+well+File.separator;
	//print("Stitch directory= "+stitchDir);
	}
//run("Grid/Collection stitching", "type=[Grid: row-by-row] order=[Right & Up] grid_size_x=4 grid_size_y=3 tile_overlap=10 first_file_index_i=1 directory="+[stitchDir]+" file_names={i}.tif output_textfile_name=TileConfiguration.txt fusion_method=[Max. Intensity] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");

//Pad zero for z position in file name
function padZero(pathImage){
indexOfZ=indexOf(listRename[i], "Z");
indexOfC=indexOf(listRename[i], "--C");
test=substring(listRename[i], indexOfZ,indexOfC);
if (lengthOf(test)<4) {
	//print(test);
	newName=substring(listRename[i], 0,indexOfZ+1 )+"0"+substring(listRename[i],indexOfZ+1,lengthOf(listRename[i]) );
	File.rename(dir1+wellList[m]+fieldList[k]+listRename[i], dir1+wellList[m]+fieldList[k]+newName);
	}
}

//Create final hyperstack
function makeHyperstack(){
run("Images to Stack", "name=Stack title=[] use");
// Change channels & number of z-slice
run("Stack to Hyperstack...", "order=xyczt(default) channels=4 slices=100 frames=1 display=Color");
Stack.setChannel(1);
run("Grays");
Stack.setChannel(2);
run("Grays");
Stack.setChannel(3);
run("Grays");
//Stack.setChannel(4);
//run("Green");
well=substring(wellList[m], 0,lengthOf(wellList[m])-1);
File.makeDirectory(dir2+wellName);
//print(fieldX, fieldY);
indexOfX=indexOf(fieldX, "X");
indexOfY=indexOf(fieldY, "Y");
X=substring(fieldX, indexOfX+1,indexOfX+3);
Y=substring(fieldY, indexOfY+1,indexOfY+3);	
intX=parseInt(X);
intY=parseInt(Y);
//print(intX,intY);
if (intX==0){
	tileNumber=1+Y;
}
if (intX==1){
	tileNumber=5+Y;
}
if (intX==2){
	tileNumber=9+Y;
}
if (intX>2){
	exit("Incorrect number of tiles !");
}	
saveAs("tiff", dir2+File.separator+well+File.separator+"tile_"+tileNumber+".tif");
print(dir2+wellName+"_field_"+fieldX+"_"+fieldY+".tif"+" saved");
run("Close All");
}
setBatchMode(false);

print("****** DONE ******");
}

macro "Stitching Well [F2]"{
print("\\Clear");
setBatchMode(true);
dir1=getDirectory("Source directory");
list=getFileList(dir1);

for (i=0; i<list.length; i++){
	currentDir=list[i];
	print(currentDir);
	if (endsWith(currentDir, "/")){
		indexSlash=indexOf(currentDir,"/");
		name=substring(currentDir, 0,indexSlash);
		name=name+".tiff";
		print("final name ="+name);
		dir=dir1+currentDir;
		run("Grid/Collection stitching", "type=[Grid: row-by-row] order=[Right & Up] grid_size_x=4 grid_size_y=3 tile_overlap=10 first_file_index_i=1 directory="+dir+" file_names=tile_{i}.tif output_textfile_name=TileConfiguration.txt fusion_method=[Max. Intensity] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");
		print("Saving file ="+dir1+currentDir+name);
		saveAs("tiff", dir1+currentDir+name);
		while (nImages>0) { 
			selectImage(nImages); 
			close(); 
		}
	}
}
print("***** DONE *****"); 
setBatchMode(false);
}

