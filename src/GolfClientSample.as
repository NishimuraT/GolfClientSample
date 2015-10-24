package
{
	import flash.display.LoaderInfo;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.system.Security;
	import flash.utils.Timer;
	
	import commands.ICommand;
	import commands.PlayDisable;
	
	import by.blooddy.crypto.serialization.JSON;
	
	import io.rocketengine.pusheras.Pusher;
	import io.rocketengine.pusheras.channel.PusherChannel;
	import io.rocketengine.pusheras.events.PusherConnectionStatusEvent;
	import io.rocketengine.pusheras.events.PusherEvent;
	import io.rocketengine.pusheras.vo.PusherOptions;
	import io.rocketengine.loggeras.logger.targets.LASBrowserConsoleTarget;
	
	CONFIG::LOGGING {
		import io.rocketengine.loggeras.logger.LAS;
		import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	}
	
	public class GolfClientSample extends Sprite
	{
		CONFIG::LOGGING {
			private static const logger:ILASLogger = LAS.getLogger(GolfClientSample);
		}
		
		private var _pusher:Pusher;
		private var _reconnectTimer:Timer;
		private var _commands:Vector.<ICommand> = new Vector.<ICommand>();
		private var _flashvars:Object; 
		
		protected const REQUIRE_OPTION:Array = [
			{"key":['playerId'], "type":"string"},
			{"key":['getStateApi'], "type":"string"},
			{"key":['blackObj'], "type":"object"},
			{"key":['blackObj', 'id'], "type":"string"},
			{"key":['blackObj', 'url'], "type":"string"}
		];
		protected const APP_KEY:String = "1d52701c98298c2dfafb";
		protected const SECURE:Boolean = true;
		protected const AUTO_PING:Boolean = true;
		protected const PING_PONG_BASED_DISCONNECT:Boolean = true;
		protected const PING_INTERVAL:Number = 750;
		protected const PING_PONG_TIMEOUT:Number = 15000;
		protected const INTERRUPT_TIMEOUT:Number = 2500;
		
		public function GolfClientSample()
		{
			stage.stageWidth = 1;
			stage.stageHeight = 1;
			
			CONFIG::LOGGING {
				LAS.addTarget(new LASBrowserConsoleTarget());
			}
			
			this.addEventListener(Event.ADDED_TO_STAGE, this_ADDED_TO_STAGE);
			this.addEventListener(Event.REMOVED, this_REMOVED);
		}
		
		protected function this_ADDED_TO_STAGE(event:Event):void
		{
			CONFIG::LOGGING {
				logger.info("Connecting ...");
			}
				
			this.removeEventListener(Event.ADDED_TO_STAGE, this_ADDED_TO_STAGE);
				
			flash.system.Security.allowInsecureDomain("*");
				
			_flashvars = LoaderInfo(this.root.loaderInfo).parameters;
			if (!ExternalInterface.available || !_flashvars) {
				return;
			}
			
			if (_flashvars.hasOwnProperty('blackObj')) {
				_flashvars.blackObj = by.blooddy.crypto.serialization.JSON.decode(_flashvars.blackObj);
			}
			
			// 必須なオプションを確認しています。
			var value:*;
			for (var i:uint = 0;i < REQUIRE_OPTION.length;i++) {
				value = _flashvars;
				for (var l:uint = 0;l < REQUIRE_OPTION[i].key.length;l++) {
					if (value.hasOwnProperty(REQUIRE_OPTION[i].key[l])) {
						value = value[REQUIRE_OPTION[i].key[l]];
					}
				}
				if (value == _flashvars || typeof value != REQUIRE_OPTION[i].type) {
					return;
				}
			}
				
			// Setup command
			this._commands.push(new PlayDisable(_flashvars));	
				
			// Setup new pusher options
			var pusherOptions:PusherOptions = new PusherOptions();
			pusherOptions.applicationKey = APP_KEY;
			pusherOptions.secure = SECURE;
			pusherOptions.autoPing = AUTO_PING;
			pusherOptions.pingPongBasedDisconnect = PING_PONG_BASED_DISCONNECT;
			pusherOptions.pingInterval = PING_INTERVAL;
			pusherOptions.pingPongTimeout = PING_PONG_TIMEOUT;
			pusherOptions.interruptTimeout = INTERRUPT_TIMEOUT;
			
			// Create pusher client and connect to server
			_pusher = new Pusher(pusherOptions);
			_pusher.verboseLogging = false;
			// Pusher event handling
			_pusher.addEventListener(PusherEvent.CONNECTION_ESTABLISHED, pusher_CONNECTION_ESTABLISHED);
			// Pusher websocket event handling
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_DISCONNECTED, pusher_WS_DISCONNECTED);
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_FAILED, pusher_WS_FAILED);
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_INTERRUPTED, pusher_WS_INTERRUPTED);
			
			// Connect websocket
			_pusher.connect();
			
			// Reconnect timer
			_reconnectTimer = new Timer(2000, 1);
			_reconnectTimer.addEventListener(TimerEvent.TIMER_COMPLETE, _reconnectTimer_TIMER_COMPLETE);
			_reconnectTimer.start();
		}
		
		/**
		 * On successful connection subscribe a new channel and hear for events
		 * */
		protected function pusher_CONNECTION_ESTABLISHED(event:PusherEvent):void
		{
			CONFIG::LOGGING {
				logger.info("Connected!");
			}
			
			// Stop the reconnect timer
			_reconnectTimer.stop();
			
			// Subscribe to a test channel and add a event listener to it.
			var channel:PusherChannel = _pusher.subscribe(_flashvars.channel);
			for (var i:uint = 0;i < this._commands.length;i++) {
				this._commands[i].channel = channel;
			}
		}
		
		protected function pusher_WS_DISCONNECTED(event:PusherConnectionStatusEvent):void
		{
			CONFIG::LOGGING {
				logger.error("Disconnected! " + by.blooddy.crypto.serialization.JSON.encode(event.data));
			}
				
			// Reconnect pusher
			_reconnectTimer.reset();
			_reconnectTimer.start();
		}
		
		protected function pusher_WS_FAILED(event:PusherConnectionStatusEvent):void
		{
			CONFIG::LOGGING {
				logger.error("Connection Failed! " + by.blooddy.crypto.serialization.JSON.encode(event.data));
			}
			
			// Reconnect pusher
			_reconnectTimer.reset();
			_reconnectTimer.start();
		}
		
		protected function pusher_WS_INTERRUPTED(event:PusherConnectionStatusEvent):void
		{
			CONFIG::LOGGING {
				logger.warn("Connection interrupt! " + by.blooddy.crypto.serialization.JSON.encode(event.data));
			}
			this._commands = null;
		}
		
		protected function _reconnectTimer_TIMER_COMPLETE(event:TimerEvent):void
		{
			CONFIG::LOGGING {
				logger.info("reconnect! ");
			}
				
			_pusher.connect();
		}
		
		protected function this_REMOVED(event:Event):void 
		{
			this.removeEventListener(Event.ADDED_TO_STAGE, this_ADDED_TO_STAGE);
			this.removeEventListener(Event.REMOVED, this_REMOVED);
			
			if (this._commands) {
				for (var i:uint = 0;i < this._commands.length;i++) {
					this._commands[i].dispose();
				}
			}
			
			if (_pusher) {
				_pusher.removeEventListener(PusherEvent.CONNECTION_ESTABLISHED, pusher_CONNECTION_ESTABLISHED);
				_pusher.removeEventListener(PusherConnectionStatusEvent.WS_DISCONNECTED, pusher_WS_DISCONNECTED);
				_pusher.removeEventListener(PusherConnectionStatusEvent.WS_FAILED, pusher_WS_FAILED);
				_pusher.removeEventListener(PusherConnectionStatusEvent.WS_INTERRUPTED, pusher_WS_INTERRUPTED);
			}
			
			if (_reconnectTimer) {
				_reconnectTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, _reconnectTimer_TIMER_COMPLETE);
			}
		}
	}
}