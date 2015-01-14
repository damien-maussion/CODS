import core.sys.posix.unistd;
import std.stdio;
import std.conv;
import core.thread;
import core.sync.semaphore;

import network;

class NetworkSimulator(int N) : INetwork {

  void delegate() [] tasks;
  int id = 0;
  int[2][N] sonToFather;
  int[2][N][N] sonToSon;
  bool[N] closed;
  Semaphore s;

  this(void delegate() [] tasks) {
    this.tasks = tasks;
    for(int i = 0; i < tasks.length; i = i+1) {
      pipe(sonToFather[i]);
      for(int j = 0; j < tasks.length; j = j+1) {
	pipe(sonToSon[i][j]);
      }
    }
    s = new Semaphore(1);
  }
  
  void start() {
    pid_t pid = 1;
    id = 0;
    while(pid != 0 && id < tasks.length) {
      pid = fork();
      if(pid != 0)
	id = id+1;
    }

    if(id < tasks.length) {
      close(sonToFather[id][0]);
      for(int i = 0; i < tasks.length; i = i+1) {
	for(int j = 0; j < tasks.length; j = j+1) {
	  if(i != id) {
	    close(sonToSon[i][j][1]); // write
	  }
	  if(j != id) {
	    close(sonToSon[i][j][0]); // read
	  }
	}
      }

      for(int i = 0; i < tasks.length; i = i+1) {
	closed[i] = false;
	Thread thread = new LookupThread(i);
	thread.start();
      }      

      tasks[id]();

      for(int i = 0; i < tasks.length; i = i+1) {
	ulong size = 0;
	core.sys.posix.unistd.write(sonToSon[id][i][1], &size, ulong.sizeof);
	close(sonToSon[id][i][1]); // write
      }
      
      bool mustWait = true;
      while(mustWait) {
	Thread.sleep(dur!("msecs")(100));
	mustWait = false;
	for(int i = 0; i < tasks.length; i = i+1) {
	  mustWait = mustWait || !closed[i];
	}
      }
      
      close(sonToFather[id][1]);

    } else {
      // The father
      int i;
      for(i = 0; i < tasks.length; i = i + 1) {
	close(sonToFather[i][1]);  /* Ferme l'extrémité d'écriture inutilisée */
      }
      bool closed = false;
      char buf;
      for(i = 0; i < tasks.length; i = i + 1) {
	while (core.sys.posix.unistd.read(sonToFather[i][0], &buf, 1) > 0) {}
	close(sonToFather[i][1]);  /* Ferme l'extrémité d'écriture inutilisée */
      }
      Thread.sleep(dur!("msecs")(100));
    }
  }
  
  void broadcast(immutable(void)[] file, bool b) {
    ulong size = file.length;
    for(int j = 0; j < N; j = j + 1) {
      if(size>0 && (b || j != id)) {
	core.sys.posix.unistd.write(sonToSon[id][j][1], &size, ulong.sizeof);
	core.sys.posix.unistd.write(sonToSon[id][j][1], cast(void*)(file), size);
      }
    }
  }

  class LookupThread : Thread
  {
    int i;

    this(int i) {
      super( &run );
      this.i = i;
    }
    
    private void run() {
      ulong size;
      char[] file;
      bool goOn = true;
      while(goOn) {
	core.sys.posix.unistd.read(sonToSon[i][id][0], &size, ulong.sizeof);
	if(size == 0){
	  goOn = false;
	} else {
	  file = new char[size];
	  core.sys.posix.unistd.read(sonToSon[i][id][0], cast(void*)(file), size);
	  // use file...
	  Network.getInstance().on_received(cast(immutable void[])(file));
	}
      }
      close(sonToSon[i][id][0]); // read
      closed[i] = true;
    }
  }
  
  int getID() {
    return id;
  }
  
}


