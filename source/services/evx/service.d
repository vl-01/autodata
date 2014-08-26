module evx.service;

// REFACTOR imports
import core.thread;
import core.sync.condition;
import std.concurrency;
import std.typecons: Tuple, tuple;
import std.traits;

import evx.utils;
import evx.meta;
import evx.math;

public {/*traits}*/
	const bool is_service (T) ()
		{/*...}*/
			import std.traits;
			return is (Unqual!T: Service);
		}
}

abstract class Service
	{/*...}*/
		public: 
		final public {/*interface}*/
			void start ()
				out {/*...}*/
					assert (this.is_running, "failed to start service (currently "~to!string(status)~")");
				}
				body {/*...}*/
					if (status == Mode.off)
						{/*...}*/
							thread = spawn (&launch);

							wait;
						}
				}

			void stop  ()
				out {/*...}*/
					assert (this.is_running.not, "failed to stop service (currently "~to!string(status)~")");
				}
				body {/*...}*/
					if (this.is_running)
						{/*...}*/
							mode = Mode.terminating; 

							foreach (callback; stop_callbacks)
								callback ();

							send (Stop.signal);
							wait;
						}
				}

			void subscribe ()
				{/*↓}*/
					(cast(shared)this).subscribe;
				}
			shared void subscribe ()
				in {/*...}*/
					assert (this.is_running, "attempted to subscribe to offline service");
				}
				body {/*...}*/
					synchronized 
						subscribers ~= cast(shared)std.concurrency.thisTid;
				}

			void on_stop (void delegate() callback)
				{/*...}*/
					stop_callbacks ~= callback;
				}
		}
		pure final {/*const}*/
			@property {/*status}*/
				Mode status ()() const
					{/*...}*/
						return mode;
					}

				bool is_running ()() const
					{/*↓}*/
						return (cast(shared)this).is_running;
					}
				shared bool is_running () const
					{/*...}*/
						with (Mode) return (this.mode & (processing | listening | self_terminated)) != 0;
					}
			}
			@property {/*id}*/
				mixin TypeUniqueId;

				Service.Id id () const
					{/*...}*/
						return service_id;
					}
				shared Service.Id id () const
					{/*↑}*/
						return (cast(Service)this).id;
					}
			}
		}
		protected:
		abstract shared {/*interface}*/
			bool initialize ();
			bool process ();
			bool listen ();
			bool terminate ();
			const string name ();
		}
		final {/*communication}*/
			final {/*transmit}*/
				void send (T...) (T message) const
					{/*...}*/
						version (VERBOSE) {/*...}*/
							static if (T.length == 1)
								string msg = to!string(message);
							else {/*...}*/
								string msg;
								foreach (i, term; message)
									static if (is (T[i] == shared))
										msg ~= T[i].stringof~", ";
									else static if (is (T[i] == Tid))
										msg ~= "tid("~tid_string(term)~"), ";
									else msg ~= to!string(term)~", ";
								msg = msg[0..$-2];
							}
							emit (this.base_info, "→ "~T.stringof~" {"~msg~"}");
						}

						static if (is (T == Stop) || is (T == bool)) // TODO bool => anything of size 1.. maybe even reject bool outright or warn on its use?
							(cast()thread).prioritySend (message);
						else (cast()thread).send (message);
					}
				shared void reply (T...) (T message)
					{/*...}*/
						version (VERBOSE) {/*...}*/
							emit (thread_info, "← "~T.stringof~" {"~to!string(message)~"}");
						}

						static if (is (T == bool))
							ownerTid.prioritySend (message);
						else ownerTid.send (message);
					}
			}
			static {/*receive}*/
				void receive (Ops...)(Ops ops)
					{/*...}*/
						void receive ()
							{std.concurrency.receive ((Stop signal){}, ops);}

						debug try receive;
							catch (Exception ex) assert (0, ex.msg);
						else receive;
					}
				bool received_before (Ops...) (Duration timeout, Ops ops)
					{/*...}*/
						auto received () 
							{return std.concurrency.receiveTimeout (timeout, (Stop signal){}, ops);}

						debug try return received;
							catch (Exception ex) assert (0, ex.msg);
						else return received;
					}
			}
		}
		protected {/*id}*/
			this ()
				{/*...}*/
					service_id = Service.Id.create;
				}
		}
		private:
		private {/*id}*/
			shared Service.Id service_id;
		}
		private {/*status}*/
			Tid thread;
			shared Mode mode;
			enum Mode {off = 0x0, initializing = 0x1, processing = 0x2, listening = 0x4, terminating = 0x8, self_terminated = 0x10}

			shared void set (Mode new_mode)
				{/*...}*/
					if (mode == Mode.terminating && new_mode != Mode.off)
						return;
					else mode = new_mode;
				}
		}
		private {/*subscribers}*/
			shared Tid[] subscribers;

			shared void notify_subscribers ()
				{/*...}*/
					foreach (tid; subscribers)
						std.concurrency.send (cast(Tid)tid, cast(Service.Id)service_id);
				}
		}
		private {/*callbacks}*/
			void delegate()[] stop_callbacks;
		}
		final {/*synchronization}*/
			static immutable auto wait_time = 2000.msecs;
			enum Sync {signal}

			auto wait ()
				{/*...}*/
					version (VERBOSE) {/*...}*/
						emit (this.base_info, "waiting...");
					}

					auto notified = std.concurrency.receiveTimeout (wait_time, (Sync signal){});

					assert (notified, "service thread failed to synchronize within "~to!string(wait_time)~" limit");

					version (VERBOSE) {/*...}*/
						emit (this.base_info, "synced");
					}
				}

			shared void sync ()
				{/*...}*/
					version (VERBOSE) {/*...}*/
						emit (thread_info, "syncing");
					}

					std.concurrency.ownerTid.prioritySend (Sync.signal);
				}

			shared void standby ()
				{/*...}*/
					version (VERBOSE) {/*...}*/
						emit (thread_info, "self-terminated. standing by...");
					}

					bool standing_by = true;
					while (standing_by)
						std.concurrency.receive ((Stop signal){standing_by = false;}, (Variant _){});
				}
		}
		final {/*launch}*/
			enum Stop {signal}

			shared void launch ()
				{/*...}*/
					version (VERBOSE) {/*...}*/
						service_threads[thisTid] = tuple (service_id, this.name);
						emit (this.base_info, "launched from tid("~tid_string!true~"):");
					}

					auto pass (alias func) ()
						{/*...}*/
							debug try return func ();
								catch (Throwable error) {/*...}*/
									writeln (`error: `, error.msg, `while`, mode, "\n", error.info);
									throw error;
								}
							else return func ();
						}

					/////////////////

					set (Mode.initializing);

					if (pass!initialize) 
						set (Mode.processing);
					else set (Mode.self_terminated);

					sync;

					while (this.processing)
						{/*...}*/
							if (pass!process)
								set (Mode.listening);
							else set (Mode.self_terminated); 

							notify_subscribers;

							while (this.listening)
								if (pass!listen)
									continue;
								else set (Mode.processing);
						}

					terminate;

					if (this.self_terminated) 
						standby;

					set (Mode.off);

					sync;
				}

			pure shared bool opDispatch (string op) () const nothrow
				{/*...}*/
					mixin (q{
						return mode == Mode.} ~op~q{;
					});
				}
		}
	};

unittest
	{/*arithmetic fail}*/
		uint x = 0;
		(x += 1) %= 2;
		assert (x == 1);
		ubyte y = 0;
		(y += 1) %= 2;
		assert (y == 0); // OUTSIDE BUG

		y += 1; 
		y %= 2;
		assert (y == 1);
	}

private version (VERBOSE) {/*...}*/
	__gshared Tuple!(Service.Id, string)[Tid] service_threads;
	private string thread_info ()
		{/*...}*/
			if (thisTid in service_threads)
				{/*...}*/
					auto info = service_threads[thisTid];
					return "tid("~tid_string~"): "~to!string(info[1])~" "~to!string(info[0]);
				}
			else return "tid("~tid_string~"): main";
		}
	private string base_info (T) (T service) if (is (Unqual!T: Service))
		{/*...}*/
			return "tid("~tid_string~"): "~(cast(shared)service).name~" "~to!string(service.id);
		}
	private void emit (string info, string msg)
		{/*...}*/
			import std.stdio;
			stderr.writeln (info~" "~msg);
			stderr.flush;
		}
}