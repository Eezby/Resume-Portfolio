import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;

public class Driver {
	public static void main(String[] args) throws FileNotFoundException 
	{
		File courseFile = new File("coscourses");					// File of all courses
		File studentFile = new File("students.txt");					// File of students and their courses
		
		Scanner courseScan = new Scanner (courseFile);					// Scanner for courses
		Scanner studentScan = new Scanner (studentFile);				// Scanner for students
		Scanner scanInput = new Scanner (System.in);					// Scanner for sentinel input
		
		String input = "";								// Input for sentinel
		
		String name = "";								// Scanned student name
		String studentCourses = "";							// Scanned student courses
												// Indexed List Linked List of courses
		IndexedListLinkedList<String> courses = new IndexedListLinkedList<String> ( );
												// Indexed List Linked List of student objects
		IndexedListLinkedList<Student> students = new IndexedListLinkedList<Student> ( );
												
		
		while(courseScan.hasNext())							// While still courses in file to scan
			courses.addLast(courseScan.nextLine());					// Add course to linked list courses
		courseScan.close();
		
		while(studentScan.hasNext()) {							// While still students in file to scan
			name = studentScan.next();
			studentCourses = studentScan.nextLine();				// Grab all courses to be read in student class
			
			Student student = new Student(name,studentCourses);			// Create a new Student object
			students.addLast(student);						// Add Student object to students linked list
		}
		studentScan.close();
		boolean found = false;
      
      while (!input.equalsIgnoreCase("XXX")) {							// While input doesn't equal sentinel value
    	  found = false;
    	  System.out.print("Input a student name: ");
    	  input = scanInput.next();								// Get input name
    	  for (int k = 0; k < students.size(); k++) {						// Loop through all students
         	 if (students.get(k).getName().equalsIgnoreCase(input)) {			// Check to see if name exists
         		 System.out.println(students.get(k).toString());
         		 found = true;
         	 }
          }
    	  
    	  if (!found && !input.equalsIgnoreCase("XXX"))						// Report name not found if found is still false
    		  System.out.println("Student name was not found");
    	  System.out.println();
      }
      
      scanInput.close();
			
	}
}
