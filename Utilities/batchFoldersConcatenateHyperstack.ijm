print("\\Clear");
setBatchMode(true);
var i=0;
var j=0;

print("**** MACRO STARTED ****");
dirMain = getDirectory("Select the directory containing the folders and images to process");
File.makeDirectory(dirMain + File.separator+ "Processed Files");

//Loop through folder and subfolder
list = getFileList(dirMain);
for (i=0; i<list.length; i++) {
	path=dirMain+list[i];
	if (endsWith(path, "/")){
		print("folder name =" + list[i]);
		print("Processing files in folder "+list[i]);
		processFile();
        }
    else {
		print("No folder to process");    	    
    }
}

function processFile() {
path = dirMain+list[i];
listFiles= getFileList(path);
lengthName=lengthOf(list[i]);
nameFile = substring(list[i], 0,lengthName-1);
print("file base name is "+nameFile);
//open all files in the folder
for (j=0; j<listFiles.length; j++){
	inputPath = path+listFiles[j];
	if (endsWith(listFiles[j] ,"merged.tif")){
	print("merged file ="+inputPath);
	}
	else {
		open(inputPath);
		}
	}
	concatenateImages();
}


function concatenateImages(){
//Concatenate them
run("Concatenate...", "all_open title=[Concatenated Stacks] open");
imageTitle=getTitle();//returns a string with the image title 
 
//split the channels
run("Split Channels");

//Adjust BC channel 3
selectWindow("C3-"+imageTitle); //green
setMinAndMax(331, 2389);
run("Apply LUT", "stack");
//run("Channels Tool...");
run("Green");
c3Title=getTitle();

//Adjust BC channel 2
selectWindow("C2-"+imageTitle); //red
//run("Brightness/Contrast...");
setMinAndMax(28, 300);
run("Apply LUT", "stack");
//run("Channels Tool...");
run("Red");
c2Title=getTitle();

//Adjust BC channel 1
selectWindow("C1-"+imageTitle); //blue
//run("Brightness/Contrast...");
setMinAndMax(85, 1135);
run("Apply LUT", "stack");
//run("Channels Tool...");
run("Blue");
c1Title=getTitle();

//run("Merge Channels...", "c1="+c1Title+" c2="+c2Title+" c3="+c3Title+" create");
run("Merge Channels...", "c1=[C1-Concatenated Stacks] c2=[C2-Concatenated Stacks] c3=[C3-Concatenated Stacks] create");
folder = "Processed Files";
outputPath = dirMain + File.separator+ folder+File.separator+nameFile+"_merged";
saveAs("Tiff", outputPath);
close();
}