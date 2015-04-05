import std.traits;
import std.conv;
import extObject;


/**
* Represents a method with its arguments.
* If f represents the method m(args), f(x) will have the same effect as x.m(args)
**/

abstract class Functor(T) {
  ExtObject execute(T);
  ExtObject applyOn(CC)(Pointer!CC) const;
  string getMethodName() const;
  string getReturnType() const;
  bool hasAttribute(string) const;
}

enum Options {
  extendsType = 0x1 << 0,
  implementsBaseInterfaces = 0x1 << 1,
  strictConst = 0x1 << 2,
}

template Observer(T : Object, int options = Options.implementsBaseInterfaces) {

  /**
  * generates the code of the class Observer!T.Type as a string
  **/

  string classCode() {
    string s = "";
    s = s ~ "import "~moduleName!T~";\n";
    s = s ~ "static void registerTypeMem() {\n";
    foreach(mem; __traits(allMembers, T)) {
      static if (is(typeof(__traits(getMember, T, mem)))) {
  enum prot = __traits(getProtection, __traits(getMember, T, mem));
  static if (prot == "public" && (mem != "__ctor")) {
    static if(isCallable!(__traits(getMember, T, mem)) && !__traits(hasMember, Object, mem)) {
      s = s ~ Member!mem.registerTypeCode() ~ "\n";
    }
  }
      }
    }
    s = s ~ "}\n";
    foreach(mem; __traits(allMembers, T)) {
      static if (is(typeof(__traits(getMember, T, mem)))) {
	enum prot = __traits(getProtection, __traits(getMember, T, mem));
	static if (prot == "public" && (mem != "__ctor")) {
	  static if(isCallable!(__traits(getMember, T, mem)) && !__traits(hasMember, Object, mem)) {
	    s = s ~ Member!mem.class_funct_mem() ~ "\n";
	  }
	}
      }
    }
    return s;
  }

  
  string newObjectCode() {

    string s = "";//  Serializer serializer;\n\n";

    /*
    s = s ~ "  void init() {\n";
    foreach(mem; __traits(allMembers, T)) {
      static if (is(typeof(__traits(getMember, T, mem)))) {
	enum prot = __traits(getProtection, __traits(getMember, T, mem));
	static if (prot == "public" && (mem != "__ctor")) {
	  static if(isCallable!(__traits(getMember, T, mem)) && !__traits(hasMember, Object, mem)) {
	    //	    s = s ~ "    serializer.register!(Funct_" ~ mem ~");\n";
	  }
	}
      }
    }

    s = s ~ "  }\n\n";
    */

    foreach(mem; __traits(allMembers, T)) {
      static if (is(typeof(__traits(getMember, T, mem)))) {
	enum prot = __traits(getProtection, __traits(getMember, T, mem));
	static if (prot == "public" && (mem != "__ctor")) {
	  static if(isCallable!(__traits(getMember, T, mem)) && !__traits(hasMember, Object, mem)) {
	    if(options & Options.extendsType) {
	      s = s ~ "override ";
	    }
	    s = s ~ Member!mem.method_mem() ~ "\n";
	    if(options & Options.extendsType) {
	      s = s ~ Member!mem.method_super_mem() ~ "\n";
	    }
	  }
	}
      }
    }
    return s;

  }



  /**
   * writes the list of inherited types and implemented interfaces
   **/
  string extention_list() {

    int param_num = 0;
    string s = "";

    if(options & Options.extendsType) {
      param_num = param_num + 1;
      s = " : " ~ fullyQualifiedName!T;
    }
    
    if(options & Options.implementsBaseInterfaces) {
      foreach (interface_name; InterfacesTuple!T) {
	param_num = param_num + 1;
	if(param_num == 1) {
	  s = " : " ~ fullyQualifiedName!interface_name;
	} else {
	  s = s ~ ", " ~ fullyQualifiedName!interface_name;
	}
      }
    }
    return s;
  }
  
  template Member(string mem) {


    string registerTypeCode() {
      return "Network.registerType!(Funct_"~mem~");\n";
    }

    /**
    * generates the class Funct_$mem
    * class Funct_$mem implements the interface Funct
    * @see Funct
    **/
    string class_funct_mem() {
      int param_num = 0;
      string s = "";

      // beginning of class Funct_$mem;
      s = s ~ "\n  class Funct_"~mem~" : Functor!("~fullyQualifiedName!T~") {\n";
      s = s ~ "\n";

      // definition of the members;
                             param_num = 0; 
                             foreach(param; ParameterTypeTuple!(__traits(getMember, T, mem))) {
      s = s ~ "    " ~ fullyQualifiedName!param ~ " param" ~ to!string(param_num) ~ ";\n";
                               param_num = param_num + 1;
                             }
      s = s ~ "\n";

      // implementation of Funct constructor;
      s = s ~ "    this(" ~ _params ~ ") {\n";
                             param_num = 0; 
                             foreach(param; ParameterTypeTuple!(__traits(getMember, T, mem))) {
      s = s ~ "      this.param" ~ to!string(param_num) ~ " = param" ~ to!string(param_num)~";\n";
                               param_num = param_num + 1; 
                             }
      s = s ~ "    }\n\n";

	
      // implementation of ExtObject Funct.execute();
      s = s ~ "    override ExtObject execute(" ~ fullyQualifiedName!T ~ " x) {\n";
      s = s ~ "      ExtObject o;\n";
                     // First case: the class extends T, we must give a special semantics to f(this)
                             if(options & Options.extendsType) {
                     // if the parameter extends Observer!T (typically 'this'), use super_mem to call the base functions
      s = s ~ "      Type y = cast(Type)(x);\n";
      s = s ~ "      if(y is null) {\n";
                               static if(returnType != "void") {
      s = s ~ "        o = x."~mem~"(" ~ params ~ ");\n";
                               } else {
      s = s ~ "        x."~mem~"(" ~ params ~ ");\n";
                               }
      s = s ~ "      } else {\n";
                               static if(returnType != "void") {
      s = s ~ "        o = y.super_"~mem~"(" ~ params ~ ");\n";
                               } else {
      s = s ~ "        y.super_"~mem~"(" ~ params ~ ");\n";
                               }
      s = s ~ "      }\n";
                     // Second case: the class does not extends T, so f(this) is type-inconsistent
			     } else {
                               static if(returnType != "void") {
      s = s ~ "      o = x."~mem~"(" ~ params ~ ");\n";
                               } else {
      s = s ~ "      x."~mem~"(" ~ params ~ ");\n";
                               }
			     }
      s = s ~ "      return o;\n";
      s = s ~ "    }\n\n";


      s = s ~ "    override ExtObject applyOn(CC)(Pointer!CC p) const {\n";
      s = s ~ "      return CC.applyMethodOnData!("~fullyQualifiedName!T~")(p, this);\n";
      s = s ~ "    }\n\n";

      // implementation of string Funct.getMethodName();
      s = s ~ "    override string getMethodName() const {\n";
      s = s ~ "      return \""~mem~"\";\n";
      s = s ~ "    }\n\n";
    
      // implementation of string Funct.getReturnType();
      s = s ~ "    override string getReturnType() const {\n";
      s = s ~ "      return \""~returnType~"\";\n";
      s = s ~ "    }\n\n";

      // implementation of bool Funct.hasAttribute(string);
      s = s ~ "    override bool hasAttribute(string attribute) const {\n";
      /*
      // Needs dmd2.66 !!!
 	                     foreach (string attr;  __traits(getFunctionAttributes, __traits(getMember, T, mem))) {
      s = s ~ "      if(attribute == \""~attr~"\") return true;\n";
	                     }
      */
                             foreach (string attr;  __traits(getAttributes, __traits(getMember, T, mem))) {
      s = s ~ "      if(attribute == \""~attr~"\") return true;\n";
                             }
      s = s ~ "      return false;\n";
      s = s ~ "    }\n\n";

      // end of class Funct_mem;
      s = s ~ "  }\n";
  
      return s;
    }


    /**
    * generates the body of the method that overloads mem in the inherited class 
    **/
    string method_mem() {
      int param_num = 0;
      string s = "";
      s = s ~ "   " ~ returnType ~ " " ~ mem ~ "(" ~ _params ~ ") {\n";
      s = s ~ "    return cast("~returnType~")(applyMethodOnObject(this, new Funct_" ~ mem ~ "(" ~ params ~ ")));\n";
      s = s ~ "  }\n";
      return s;
    }

    /**
    * generates the body of the super_mem method that accedes the method mem in the base class 
    **/
    string method_super_mem() {
      int param_num = 0;
      string s = "";
      s = s ~ "  private " ~ returnType ~ " super_" ~ mem ~ "(" ~ _params ~ ") {\n";
      s = s ~ "    return super." ~ mem ~ "(" ~ params ~ ");\n";
      s = s ~ "  }\n";
      return s;
    }

    /**
    * writes the parameters of the method separed by a comma, e.g. "param0, param1, param2"
    **/
    string params() {
      string result = "";
	for(int i=0; i< arity!(__traits(getMember, T, mem)); i++) {
	  if(i > 0) {
	    result = result ~ ", "; 
 	  }
          result = result ~ "param" ~ to!string(i);
	}
      return result;
    }

    /**
    * writes the parameters of the method separed by a comma with their types, e.g. "int param0, char param1, double param2"
    **/
    string _params() {
      string result = "";
      int param_num = 0;
      foreach(param; ParameterTypeTuple!(__traits(getMember, T, mem))) {
        if(param_num > 0) { result = result ~ ", "; }
        result = result ~ fullyQualifiedName!param ~ " param" ~ to!string(param_num);
        param_num = param_num + 1;
      }
      return result;
    }

    /**
    * returns the return type of the method
    **/
    const returnType = fullyQualifiedName!(ReturnType!(__traits(getMember, T, mem)));

  }
}
