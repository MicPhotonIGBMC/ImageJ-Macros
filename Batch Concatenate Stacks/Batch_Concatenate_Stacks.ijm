/* BatchConcatenateStacks_
 * This ImageJ macro concatenates splitten (to have less than 2 GB) 
 * Metamorph z-stacks from input folder and saves results to output folder.
 * This version is limited to z-stacks splitten to at most 3 substacks.
 * A version braking this limit may be developped in the future. 
 * Author Marcel Boeglin - December 2019
*/

var macroName = "BatchConcatenateStacks_";
var copyright = "Author Marcel Boeglin - December 2019";
var version = "02";
var fileList, extensionLessFileList;
var dir1, dir2;
var extension = ".TIF";
var splittenIn3 = false;
var startTime;
/* stack size is at most 2 GB */
var listOfFirstStacks, listOfSecondStacks,  listOfThirdStacks;

execute();

function getParams() {
	Dialog.create(macroName);
	Dialog.addString("Extension of stack files to be processed", extension);
	Dialog.show();
	extension = Dialog.getString();
}

function execute() {
	startTime = getTime();
	getDirs();
	getParams();
	print("\\Clear");
	print(macroName+version);
	print(copyright);
	print("\nExtension of stack files to be processed: "+extension);
	print("Input dir: "+dir1);
	print("Output dir: "+dir2);
	fileList = getFiles(dir1);
	print("\nInput dir file list");
	printArray("fileList", fileList);
	fileList = filterList(fileList, extension, "");//removes non tif or stk files
	print("\nExtension-filtered input dir file list");
	printArray("fileList", fileList);
	extensionLessFileList = removeExtensions(fileList);
	listOfFirstStacks = getFirstStacksList(extensionLessFileList);
	print("\nInput dir first stack names");
	printArray("listOfFirstStacks", listOfFirstStacks);
	listOfSecondStacks = getSecondStacksList(extensionLessFileList);
	print("\nInput dir second stack names");
	printArray("listOfSecondStacks", listOfSecondStacks);
	listOfThirdStacks = getThirdStacksList(extensionLessFileList);
	if (listOfThirdStacks.length>0) {
		splittenIn3 = true;
		print("\nInput dir third stack names");
		printArray("listOfThirdStacks", listOfThirdStacks);
	}
	setBatchMode(true);
	print("\nConcatenating stack groups and saving results in output folder");
	for (i=0; i<listOfFirstStacks.length; i++) {
		groupTime = getTime();
		open(dir1+listOfFirstStacks[i]+extension);
		t1 = getTitle();
		open(dir1+listOfSecondStacks[i]+extension);
		t2 = getTitle();
		t3 = "";
		if(splittenIn3) {
			open(dir1+listOfThirdStacks[i]+extension);
			t3 = getTitle();
			run("Concatenate...", "open image1="+t1+" image2="+t2+" image3="+t3);
		}
		else
			run("Concatenate...", "open image1="+t1+" image2="+t2);
		saveAs("tiff", dir2+t1);
		close();
		print("Group "+i+" : process time : "+((getTime()-groupTime)/1000)+"s");
		print("Ellapsed time : "+((getTime()-startTime)/1000)+"s");
		saveLog();
	}
	finish();
	setBatchMode(false);
}

function printArray(arrayName, array) {
	//print("");
	for (i=0; i<array.length; i++)
		print(arrayName+"["+i+"] = "+array[i]);
}

function finish() {
	print("\n"+macroName+" done.\nTotal process time: "+
			((getTime()-startTime)/1000)+"s");
	saveLog();
}

function saveLog() {
	selectWindow("Log");
	logname = macroName+"Log";
//	str = concatenateFileFilters(fileFilter, excludingFilter); logname += str;
	saveAs("Text", dir2+logname+".txt");
}

function getDirs() {
	dir1 = getDirectory("Choose Source Directory ");
	dir2 = getDirectory("Choose Destination Directory ");
	while (dir2==dir1) {
		showMessage("Destination folder must be different from source");
		dir2 = getDirectory("Choose Destination Directory ");
	}
}

function getFiles(dir) {
	list = getFileList(dir);
	if (list.length==0) {
		showMessage(macroName,"Input folder:\n"+dir+"\nseems empty");
		exit();
	}
	j=0;
	list2 = newArray(list.length);
	for (i=0; i<list.length; i++) {
		s = list[i];
		if (File.isDirectory(dir+s)) continue;
		list2[j] = s;
		j++;
	}
	if (j<1) {
		showMessage(macroName,"Input folder:\n"+dir+
			"\nseems empty or to contain only subfolders");
		exit();
	}
	for (i=0; i<list2.length; i++) {
		list2[i] = toString(list2[i]);
	}
	list2 = Array.trim(list2, j);
	list2 = Array.sort(list2);
	return list2;
}

function filterList(list, extension) {
	a = newArray(list.length;
	k = 0;
	for (i=0; i<list.length; i++) {
		str = list[i];
		if (!endsWith(str, extension)) continue;
		a[k++] = str;
	}
	a = Array.trim(a, k);
	a = Array.sort(a);
	return a;
}


function getFirstStacksList(extensionLessFiles) {
	a = newArray(extensionLessFiles.length);
	k = 0;
	for (i=0; i<extensionLessFiles.length; i++) {
		str = extensionLessFiles[i];
		if (endsWith(str, "-file002")) continue;
		if (endsWith(str, "-file003")) continue;
		a[k++] = str;
	}
	a = Array.trim(a, k);
	a = Array.sort(a);
	return a;
}

function getSecondStacksList(extensionLessFiles) {
	a = newArray(extensionLessFiles.length);
	k = 0;
	for (i=0; i<extensionLessFiles.length; i++) {
		str = extensionLessFiles[i];
		if (endsWith(str, "-file002")) a[k++] = str;
	}
	a = Array.trim(a, k);
	a = Array.sort(a);
	return a;
}

function getThirdStacksList(extensionLessFiles) {
	a = newArray(extensionLessFiles.length);
	k = 0;
	for (i=0; i<extensionLessFiles.length; i++) {
		str = extensionLessFiles[i];
		if (endsWith(str, "-file003")) a[k++] = str;
	}
	a = Array.trim(a, k);
	a = Array.sort(a);
	return a;
}

/** Returns TIFF and STK files contained in list not matching excludingFilter
* and matching fileFilter */
function filterList(list, fileFilter, excludingFilter) {
	list2 = newArray(list.length);
	j=0;
	for (i=0; i<list.length; i++) {
		s = list[i];
		if (fileFilter!="" && indexOf(s, fileFilter)<0) continue;
		if (excludingFilter!="" && indexOf(s, excludingFilter)>=0) continue;
		s2 = toLowerCase(s);
		//ext = getExtension(s);
		if (!endsWith(s2, ".tif") && !endsWith(s2, ".stk")) continue;
		list2[j] = s;
		j++;
	}
	if (j<1) {
		showMessage(macroName,
				"Input folder seems not to contain TIFF or STK files "+
				"matching "+fileFilter);
		exit();
	}
	for (i=0; i<list2.length; i++) {
		list2[i] = toString(list2[i]);
	}
	list2 = Array.trim(list2, j);
	list2 = Array.sort(list2);
	return list2;
}

function removeExtensions(files) {
	files2 = newArray(files.length);
	for (i=0; i<files.length; i++) {
		str = files[i];
		if (indexOf(str, ".")<0) files2[i] = str;
		else  files2[i] = substring(str, 0, lastIndexOf(str, "."));
	}
	return files2;
}

















