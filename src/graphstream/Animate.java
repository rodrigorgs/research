import org.graphstream.graph.*;
import org.graphstream.graph.implementations.*;
import org.graphstream.stream.file.*;
import org.graphstream.stream.file.FileSinkImages.*;

public class Animate {
  static String style = 
    "node.project { fill-color: black; }" +
    "node.developer { fill-color: red; }" +
    "graph { padding: 50px; }" +
    "edge { fill-color: gray; }";

  static double layoutForce = 0.2;

  public static void animate(String filename, int milliseconds) throws Exception {
		Graph graph = new SingleGraph("Rodrigo");	
		graph.display();
		graph.addAttribute("ui.antialias");
    graph.addAttribute("ui.stylesheet", style);

    System.out.println(graph.getAttribute("layout.force"));
    graph.addAttribute("layout.force", layoutForce); 

		try {

	        FileSource source = FileSourceFactory.sourceFor(filename);
	        source.addSink( graph );
	        source.begin(filename);
	        while( source.nextStep() ) { Thread.sleep(milliseconds); }
	        source.end();
        } catch( Exception e ) { e.printStackTrace(); }
  }

  public static void saveImages(String dgsFilename, String prefix) throws Exception {
    // FileSinkImages arguments

    OutputPolicy outputPolicy = OutputPolicy.ByStepOutput;
    OutputType type = OutputType.PNG;
    Resolution resolution = Resolutions.HD720;

    FileSinkImages fsi = new FileSinkImages(
    prefix, type, resolution, outputPolicy );

    // Create the source

    FileSourceDGS dgs = new FileSourceDGS();

    // Optional configuration

    fsi.setStyleSheet(style);

    fsi.setLayoutPolicy( LayoutPolicy.ComputedAtNewImage );
    fsi.setHighQuality();

    // Images production

    dgs.addSink( fsi );

    dgs.begin(dgsFilename);
    int i = 0;
    while( dgs.nextStep() );
    dgs.end();
  }

  public static void help() {
    System.err.println("Usage: ");
    System.err.println("    java Animate display <dsg> <milliseconds> ");
    System.err.println("or ");
    System.err.println("    java Animate save <dsg> <prefix>");
    System.exit(1);
  }

	public static void main(String args[]) throws Exception {
    if (args.length < 3) {
      help();
    }

    if (args[0].equals("display")) {
      String filename = args[1];
      int milliseconds = Integer.parseInt(args[2]);
      animate(filename, milliseconds);
    }
    else if (args[0].equals("save")) {
      String filename = args[1];
      String prefix = args[2];
      saveImages(filename, prefix);
    }
  }

}
