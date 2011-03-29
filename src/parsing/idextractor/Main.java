package idextractor;

import japa.parser.JavaParser;
import japa.parser.ast.CompilationUnit;
import japa.parser.ast.body.ClassOrInterfaceDeclaration;
import japa.parser.ast.body.FieldDeclaration;
import japa.parser.ast.body.MethodDeclaration;
import japa.parser.ast.body.VariableDeclarator;
import japa.parser.ast.visitor.VoidVisitorAdapter;

import java.io.File;
import java.io.FileInputStream;
import java.util.Arrays;
import java.util.Vector;

class Main {
	
	public static void helpAndExit() {
		System.err.println("Parameter: [ files | directories ]");
		System.err.println();
		System.exit(1);
	}

    public static void main(String[] args) throws Exception {
    	if (args.length < 1)
    		helpAndExit();
    	
    	Vector<String> fileList = new Vector<String>(Arrays.asList(args));
    	
    	while (!fileList.isEmpty()) {
    		String filename = fileList.remove(0);
    		File file = new File(filename);
    		
    		if (filename.equals(".") || filename.equals(".."))
    			continue;
    		
    		if (file.isDirectory()) {
    			for (String innerFile : file.list()) {
    				String path = file.getAbsolutePath() + File.separator + innerFile; 
    				fileList.add(path);
    			}
    		}
    		else if (filename.endsWith(".java")) {
    			FileInputStream in = new FileInputStream(file);
    			
    	        CompilationUnit cu;
    	        try {
    	            // parse the file
    	            cu = JavaParser.parse(in);
    	        } finally {
    	            in.close();
    	        }

    	        // visit and print the methods names
    	        new MyVisitor(file.getAbsolutePath()).visit(cu, null);
    		}
    	}
    }

    /**
     * Simple visitor implementation for visiting MethodDeclaration nodes. 
     */
    private static class MyVisitor extends VoidVisitorAdapter {
    	private String filename;
    	
    	public MyVisitor(String filename) {
			this.filename = filename;
		}
    	
        @Override
        public void visit(MethodDeclaration n, Object arg) {
            System.out.println(n.getName() + ";method;" + filename);
            super.visit(n, arg);
        }
        
        @Override
        public void visit(FieldDeclaration n, Object arg) {
        	for (VariableDeclarator var : n.getVariables()) {
        		System.out.println(var.getId().getName() + ";field;" + filename);
        	}
        	super.visit(n, arg);
        }
        
        @Override
        public void visit(ClassOrInterfaceDeclaration n, Object arg) {
        	System.out.println(n.getName() + ";module;" + filename);
        	super.visit(n, arg);
        }
    }
}