package dev.mcserver.core;

import org.bukkit.ChatColor;
import org.bukkit.Location;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.java.JavaPlugin;

public final class NetworkCorePlugin extends JavaPlugin implements Listener {
    @Override
    public void onEnable() {
        saveDefaultConfig();
        getServer().getPluginManager().registerEvents(this, this);
        getLogger().info("Network Core enabled. Commands: /network, /spawn");
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent event) {
        if (getConfig().getBoolean("features.welcome-message", true)) {
            event.getPlayer().sendMessage(color(getConfig().getString("messages.welcome",
                    "&aWelcome to &fMC-SERVER&a! Use &f/network&a for help.")));
        }
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (command.getName().equalsIgnoreCase("network")) {
            sender.sendMessage(color("&a&lMC-SERVER &8| &7Network test build"));
            sender.sendMessage(color("&7Commands: &f/network &7and &f/spawn"));
            sender.sendMessage(color("&7Server: &f" + getServer().getName()));
            return true;
        }
        if (command.getName().equalsIgnoreCase("spawn")) {
            if (!(sender instanceof Player player)) {
                sender.sendMessage("This command can only be used by a player.");
                return true;
            }
            Location spawn = player.getWorld().getSpawnLocation();
            player.teleportAsync(spawn).thenAccept(success -> {
                if (success) player.sendMessage(color("&aTeleported to world spawn."));
                else player.sendMessage(color("&cCould not teleport to spawn."));
            });
            return true;
        }
        return false;
    }

    private String color(String message) {
        return ChatColor.translateAlternateColorCodes('&', message == null ? "" : message);
    }
}
