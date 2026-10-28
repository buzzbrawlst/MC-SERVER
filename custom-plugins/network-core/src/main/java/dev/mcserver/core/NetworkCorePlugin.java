package dev.mcserver.core;

import org.bukkit.plugin.java.JavaPlugin;

/** Safe starting point; gameplay modules should be added with tests and documented settings. */
public final class NetworkCorePlugin extends JavaPlugin {
    @Override
    public void onEnable() {
        saveDefaultConfig();
        getLogger().info("MC-SERVER Network Core enabled. No gameplay modules are enabled yet.");
    }

    @Override
    public void onDisable() {
        getLogger().info("MC-SERVER Network Core disabled.");
    }
}
