import orange.serialization._;
import orange.serialization.archives._;
import std.stdio;
import std.conv;




abstract class Message {
  void on_receive();
}


interface INetwork {
  void broadcast(immutable(void)[] file, bool b);
  int getID();
}



class Network {
  
  static {
    __gshared Network defaultNetwork;
    public Network getInstance() {
      if(!defaultNetwork) {
        defaultNetwork = new Network();
      }
      return defaultNetwork;
    }
    public void configure(INetwork network) {
      getInstance.setNetwork(network);
    }
    public void registerType(T : Object)() {
      getInstance.registerNewType!T();
    }
  }
    
  private void function (Serializer serializer) [ClassInfo] registeredTypes;
  private INetwork network;

  this() {
    network = null;
  }
    
  public void registerNewType(T : Object)() {
    registeredTypes[T.classinfo] = (Serializer s){s.register!T();};
  }

  public void writeRegistered(string s) {
    /*    foreach(ClassInfo ci; registeredTypes.keys) {
      writeln(ci);
      }*/
    writeln(s ~ to!string(registeredTypes.length));
  }

  public void setNetwork(INetwork network) {
    this.network = network;
  }


  //Function which serializes a message
  private immutable(void)[] serialize_update(Message m) {
    XmlArchive!char archive = new XmlArchive!(char);
    Serializer serializer = new Serializer(archive);
    foreach (void function (Serializer) f ; registeredTypes) {
      f(serializer);
    }
    serializer.serialize(m);
    auto file = archive.untypedData();
    //    writeln(archive.data);
    return file;
  }
  
  //Unserialize a message and deliver it
  public void on_received(immutable (void)[] file) {
    XmlArchive!char archive = new XmlArchive!(char);
    Serializer serializer = new Serializer(archive);
    foreach (void function (Serializer) f ; registeredTypes) {
      f(serializer);
    }
    Message m = serializer.deserialize!(Message)(file);
    m.on_receive();
  }
  

  void broadcast(Message m, bool b) {
    auto file = serialize_update(m);
    network.broadcast(file, b);
  }

  int getID() {
    return network.getID();
  }
  
}

