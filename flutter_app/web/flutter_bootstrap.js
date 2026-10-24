{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('bahtzay-startup')?.remove();
    } catch (error) {
      document.getElementById('startup-message').textContent = 'App ဖွင့်မရသေးပါ။ ပြန်စမ်းပေးပါ။ / Unable to open. Please retry.';
      document.getElementById('startup-retry').hidden = false;
      console.error('App startup failed', error);
    }
  }
});
