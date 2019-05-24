/* Code from 
 *  Bram van den Broek
 *  Advanced Microscopy and Image Analysis
 *  BioImaging Facility / Cell Biology
 *  The Netherlands Cancer Institute 
 *  http://imagej.1557.x6.nabble.com/Writing-ImageJ-Macros-a-better-way-td5020818.html
 * 
 */


debug_mode = true;
n=1;

// code
checkpoint("before filter");
// more code
checkpoint("after filter");
// more code
checkpoint("");
// more code

function checkpoint(message) {
        if(debug_mode==true) {
                setBatchMode("show"); //If you run your macro in Batch mode.
                print("Checkpoint "+n+" reached");
                waitForUser("Checkpoint "+n+": "+message);
                setBatchMode("hide"); //If you run your macro in Batch mode.
                n++;
        }
} 