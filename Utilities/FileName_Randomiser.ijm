/* Code from Jason Early
 * CNR, Edinburgh,UK
 *  
 * 
*/

var myDir,currentFldr, tbl, removeLabs, csvTab;

macro " Filename_Randomiser [F6]" {
    setBatchMode(true);
    Dialog.create("File type");
    Dialog.addString("File extension: ", ".czi", 5);
    Dialog.addString("Output prefix: ", "Randomised_", 30);
    Dialog.addCheckbox("Remove internal file labels for every slice (takes longer and file type must be compatible with ImageJ)", false);
    Dialog.show();
    ext = Dialog.getString();
    prefix = Dialog.getString();
    
    removeLabs = Dialog.getCheckbox();
    chosenDir = getDirectory("Choose a Directory");
    start = getTime();
    csvTab = makeUniqueFile(myDir, "Randomised_list.csv");
    makeNewDir(chosenDir);
    makeTable();
    processFiles(chosenDir, ext, prefix);
    close(prefix+"*");
    stop = getTime();
    showStatus("Finished... ("+((stop-start)/1000)+" seconds)");
    setBatchMode(false);  
    selectWindow("Randomised_list.csv");
    saveAs("Text", chosenDir+"Randomised_list.csv");
    selectWindow("Randomised_list.csv");
    run("Close");
}

// functions 

function makeNewDir(dir) {
  upDir=File.getParent(dir);
  endCFName=lengthOf(chosenDir)-1;
  startCFName=lengthOf(upDir);
  currentFldr=substring(chosenDir,startCFName,endCFName);
  myDir=upDir+File.separator+ currentFldr +"_Randomised"+File.separator;
  if(File.exists(myDir))
       showMessageWithCancel("A folder named:\n"+myDir+"\nAlready exists...\n \nOverride?");
  File.makeDirectory(myDir);
}
 
function makeTable() {
  tb="Randomised_list.csv"; tbl="["+tb+"]";
  File.append(",Headings:#,Original Title,Randomised Title,Original Directory,New Directory", myDir+csvTab);
  if(isOpen(tb)) print(tbl, "\\Clear");
  else {
  run("New... ", "name="+tbl+" type=Table");
  print(tbl, "\\Headings:#\tOriginal Title\tRandomised Title\tOriginal Directory\tNew Directory");
  }
}

function processFiles(dir, ext, prefix){
  list = getFileList(dir);
  tempList = newArray(list.length);
  for(i=0, n=0; i<list.length; i++){
    if(endsWith(list[i], ext)){
      tempList[n] = list[i];
      n++;
    }
  }
  length = lengthOf(toString(n+1));
  imageList = Array.trim(tempList, n);
  tempArray = Array.getSequence(imageList.length);
  newNames = shuffleArray(tempArray);
  for(i=0; i<imageList.length; i++){
    if(!endsWith(imageList[i], "/")){
        processFile(dir, myDir, imageList[i], prefix+IJ.pad(newNames[i], length), ext);
    }
  }
}

function processFile(oldDir, newDir, oldname,newname, ext) {
  if(File.exists(newDir+newname+ext)==false){
    if(removeLabs == true){
      run("Bio-Formats Importer", "open=["+oldDir+oldname+"] color_mode=Default view=Hyperstack stack_order=XYCZT");//use_virtual_stack");
      image = getImageID();
      removeLabels(newname,image);
      saveAs("Tiff", newDir+newname+".tif");
      print(tbl, i+1+"\t"+oldname+"\t" +newname+".tif"+"\t" + oldDir +"\t"+ newDir);
      File.append(i+1+","+oldname+"," +newname+".tif"+"," + oldDir +","+ newDir, newDir+csvTab);
      close();
    }
    else{
        print(tbl, i+1+"\t"+oldname+"\t" +newname+ext+"\t" + oldDir +"\t"+ newDir);
        File.append(i+1+","+oldname+"," +newname+ext+"," + oldDir +","+ newDir, newDir+csvTab);
        File.copy(oldDir+oldname, newDir+newname+ext);
      }
    }
  else print("Could not process "+oldname+" as a file named "+newname+ext+" already exists in the output directory.");
}

function randomise(array) {
  for (i=0; i<array.length; i++) {
    n =round(array.length*random*(1000000));
    m=toString(n)+"_"+toString(i+1);
    while(lengthOf(m)<10) m= "0"+m;
    
    array[i]=m;}
   return array;
}

function removeLabels(newLabel,ID){
  selectImage(ID);
  getDimensions(width, height, channels, slices, frames);
  for(f=0; f<frames; f++){
    Stack.setFrame(f+1);
    for(z=0; z<channels; z++){
      Stack.setChannel(z+1);
      for(s=0; s<slices; s++){
        Stack.setSlice(s+1);
        label = getInfo("slice.label");
        label = newLabel+"\n"+label;
        setMetadata("Label", label);
//        print(label);
      }
    }
  }
}

function makeUniqueFile(dir, file){
  i=0;
  while(File.exists(dir+file)){
    i++;
    file = toString(i)+"_"+file;
  }
  return file;
}

function randomNum(length, array){
    unique = false;
    while(unique==false){
      n = toString(round(array.length*random*(100000)));
      while(lengthOf(n)<10) n= "0"+n;
      test = true;
      for(i=0; i<array.length; i++){
        if(array[i]==n){
          test = false;
          print("Duplicate");
        }
      }
      if(test==true) unique = true;
    }
}

function shuffleArray(in){
//http://stackoverflow.com/questions/26718637/populate-array-with-unique-random-numbers-javascript
  inArray = "";
  for(i=0;i<in.length;i++){
    if(i>0&&i<in.length) inArray = inArray+",";
    inArray = inArray+in[i];
  }
  test = eval("script", "var myArray = ["+inArray+"];\nnewArray = shuffle(myArray);\nnewArray.toString();\nfunction shuffle(o){\n    for(var j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);\n    return o;\n};");
  outArray = split(test,",");
  return outArray;
}
