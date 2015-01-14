import std.stdio;
import std.typecons;
import std.conv;

/*
 * Update_list is a linked list of (int, int, T) elements, sorted the lexicographic order over (int, int).
 */

template Update_list(T) {
  class Update_list {
    private Update_list tail;
    private int clock_head;
    private int proc_head;
    private T update_head;
    private bool empty = true;
    
    this(){tail = null; clock_head = 0; proc_head = 0; empty = true;}

    this(int cl, int i, T t) {tail = new Update_list(); clock_head = cl; proc_head = i; update_head = t; empty = false;}
    this(int cl, int i, T t, Update_list l) {tail = l; clock_head = cl; proc_head = i; update_head = t; empty = false;}
    this(int cl, int i, T t, Update_list l, bool b) {tail = l; clock_head = cl; proc_head = i; update_head = t; empty = b;}
    
    public bool isEmpty() {return empty;}
    public int get_clock_head(){return clock_head;}
    public int get_proc_head(){return proc_head;}
    public T get_update_head(){return update_head;}
    //public Tuple!(int, int, T) getHead(){return (tuple!(clock_head, proc_head, update_head));}
    public Update_list getTail(){return tail;}
    public Tuple!(int, int, T) pull(){
      (assert (!empty)); // prevent that pull is invoked over an empty list
      int cl = clock_head;
      int i = proc_head;
      T u = update_head;
      Update_list l_bis = tail;
      this.empty = l_bis.empty;
      if (!empty) {
	clock_head = l_bis.get_clock_head();
	proc_head = l_bis.get_proc_head();
	update_head = l_bis.get_update_head();
	this.tail = l_bis.getTail();
      }
      return (tuple(cl, i, u));
    }

    //push return false if the element wasn't in the list, true if it already was
    public bool push(int cl, int i, T t){
      if (empty) {
	tail = new Update_list();
	clock_head = cl;
	proc_head = i;
	update_head = t;
	empty = false;
	return false;
      }
      else {
	if (cl > clock_head || (cl == clock_head && i > proc_head)){return tail.push(cl, i, t);}
	else {
	  /*
	    The next if is to ensure that we do not add the same object twice.
	    We do not need to check f since a process i can only make one
	    update/query for a given clock time cl.
	   */
	  if (!(cl == clock_head && i == proc_head)){
	  tail = new Update_list(clock_head, proc_head, update_head, tail);
	  
	  clock_head = cl;
	  proc_head = i;
	  update_head = t;
	  return false;
	  }
	  else {return true;}
	}
      }
    }

    //push return false if the element wasn't in the list, true if it already was
    public bool isAlreadyIn(int cl, int i, T t){
      if (empty) {
	return false;
      }
      else {
	if (cl > clock_head || (cl == clock_head && i > proc_head)){return tail.isAlreadyIn(cl, i, t);}
	else {
	  if (!(cl == clock_head && i == proc_head)){
	  return false;
	  }
	  else {return true;}
	}
      }
    }
    
    public Update_list copy(){
      return new Update_list(clock_head, proc_head, update_head, tail, empty);
    }
    
    
    override public string toString(){
      string s = "";
      if (!empty) {
	s = s ~ "(";
	s = s ~ to!string(clock_head) ~ ";";
	s = s ~ to!string(proc_head);
	//s = s ~ to!string(proc_head) ~ ";";
	//s = s ~ to!string(update_head);
	s = s ~ ") ";
      if (!(tail is null)) {s = s ~ tail.toString();}
      }
      return s;
    }
  }
}
