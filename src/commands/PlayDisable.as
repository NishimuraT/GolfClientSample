package commands
{
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Timer;
	
	import by.blooddy.crypto.serialization.JSON;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.pusheras.channel.PusherChannel;
	import io.rocketengine.pusheras.events.PusherEvent;
	
	public class PlayDisable implements ICommand
	{
		CONFIG::LOGGING {
			private static const logger:ILASLogger = LAS.getLogger(PlayDisable);
		}
		
		private static const EVENT_NAME:String = "PLAY_DISABLE";
		private var _channel:PusherChannel;
		private var _timer:Timer;
		private var _disabled:Boolean = true;
		
		private var _flashvars:Object;
		private var _jsApiPrefix:String;
		
		public function PlayDisable(flashvars:Object)
		{
			this._flashvars = flashvars;
			this._jsApiPrefix = "ulizaplayer('" + this._flashvars.playerId + "')";
			
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE , function (e:Event):void {
				CONFIG::LOGGING {
					logger.info("respose isDisable api data=" + urlLoader.data);
				}
				_disabled = urlLoader.data == "1" ? true : false;
			});
			urlLoader.load(new URLRequest(flashvars.getStateApi));
			
			ExternalInterface.addCallback('playDisable', this._onJSPlayDisable);
			
			_timer = new Timer(3000, 0);
			_timer.addEventListener(TimerEvent.TIMER, _polling);
			_timer.start();
		}
		
		public function set channel(channel:PusherChannel):void 
		{
			this._channel = channel;
			this._channel.addEventListener(EVENT_NAME, _onReceiveMessage);
		}
		
		public function dispose():void
		{
			this._channel.removeEventListener(EVENT_NAME, _onReceiveMessage);
			ExternalInterface.addCallback('playDisable', null);
			_timer.removeEventListener(TimerEvent.TIMER,_polling);
			_timer.stop();
		}
		
		// private -----------------------------------------------------------------
		
		private function _polling(event:TimerEvent):void 
		{
			CONFIG::LOGGING {
				logger.info("polling.. ");
			}
			try {
				if (!_isJsBrige()) {
					return;
				}
				if (this._hasButton(_flashvars.startButtonId)) {
					ExternalInterface.call(this._jsApiPrefix + ".removeButton", _flashvars.startButtonId);
					_playerDisable(false);
				}
				
				if (this._hasButton(_flashvars.blackObj.id) != this._disabled) {
					CONFIG::LOGGING {
						logger.info("change state. disabled=" + this._disabled);
					}
					_playerDisable(this._disabled);
				}
			} catch(err:Error) {
				CONFIG::LOGGING {
					logger.info("JSBrige Failed! (PlayDisable01)");
				}
			}
		}
		
		private function _playerDisable(disable:Boolean):void 
		{
			if (disable) {
				ExternalInterface.call(this._jsApiPrefix + ".media.setStyle", {'mediaView':{'show':false}});
				ExternalInterface.call(this._jsApiPrefix + ".media.updateDisplay");
				ExternalInterface.call(this._jsApiPrefix + ".addButton", _flashvars.blackObj);
			} else {
				ExternalInterface.call(this._jsApiPrefix + ".media.setStyle", {'mediaView':{'show':true}});
				ExternalInterface.call(this._jsApiPrefix + ".media.updateDisplay");
				ExternalInterface.call(this._jsApiPrefix + ".removeButton", _flashvars.blackObj.id);
			}
		}
		
		private function _hasButton(buttonId:String):Boolean {
			try {
				var buttonInfo:Object = ExternalInterface.call(this._jsApiPrefix + ".getButtonInfo");
				if (!!buttonInfo && typeof buttonInfo == 'object') {
					for (var i:uint=0;i < buttonInfo.length;i++) {
						if (buttonInfo[i].id == buttonId) {
							return true;
						}
					}
				}
			} catch(err:Error) {
				CONFIG::LOGGING {
					logger.info("JSBrige Failed! (PlayDisable02)");
				}
			}
			return false;
		}
		
		private function _isJsBrige():Boolean { 
			try {
				return !!ExternalInterface.call(this._jsApiPrefix + ".jsBridgeAvailable");
			} catch(err:Error) {
				CONFIG::LOGGING {
					logger.info("JSBrige Failed! (PlayDisable03)");
				}
			}
			return false;
		}
		
		private function _onReceiveMessage(event:PusherEvent):void 
		{
			CONFIG::LOGGING {
				logger.info("on Receive Message! " + by.blooddy.crypto.serialization.JSON.encode(event.data));
			}
				
			if (event.data.hasOwnProperty('disable')) {
				this._disabled = event.data.disable;
			}
		}
		
		private function _onJSPlayDisable(value:Boolean):void 
		{
			this._disabled = value;
		}
		
		// private -----------------------------------------------------------------
	}
}