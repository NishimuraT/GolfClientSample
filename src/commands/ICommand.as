package commands
{
	import io.rocketengine.pusheras.channel.PusherChannel;

	public interface ICommand
	{	
		function dispose():void;
		function set channel(channel:PusherChannel):void;
	}
}