using System;
using System.Reflection;
using System.Threading;
using System.Runtime.CompilerServices;
namespace MauiHello;

public partial class MainPage : ContentPage
{
	int count = 0;

	public MainPage()
	{
		InitializeComponent();
	}

	private void OnCounterClicked(object sender, EventArgs e)
	{
                CounterBtn.Text = $"Racing 4 threads";
                int n = RaceThreads();
                string mode;
                if (RuntimeFeature.IsDynamicCodeSupported)
                {
                        if (RuntimeFeature.IsDynamicCodeCompiled)
                        {
                                mode = "JIT";
                        }
                        else
                        {
                                mode = "Interp";
                        }
                }
                else
                {
                        mode = "AOT";
                }
                CounterBtn.Text = $"Got {n} successes, {mode}";
	}

        private static int RaceThreads()
        {
                const int N = 4;
                SemaphoreSlim go = new(0, N);
                bool[] results = new bool[N];
                Thread[] threads = new Thread[N];
                var an = new AssemblyName("RacingLib");
#if true
                threads[0] = new Thread(() => {
                        go.Wait();
                        var assm = Assembly.Load(an);
                        var ty = assm.GetType("RacingLib.Class1");
                        var mi = ty.GetMethod("Method", BindingFlags.Public | BindingFlags.Static);
                        results[0] = (bool) mi.Invoke (null, Array.Empty<object>());
                });
                threads[1] = new Thread(() => {
                        go.Wait();
                        var assm = Assembly.Load(an);
                        var ty = assm.GetType("RacingLib.Class2");
                        var mi = ty.GetMethod("Method", BindingFlags.Public | BindingFlags.Static);
                        results[1] = (bool) mi.Invoke (null, Array.Empty<object>());
                });
                threads[2] = new Thread(() => {
                        go.Wait();
                        var assm = Assembly.Load(an);
                        var ty = assm.GetType("RacingLib.Class3");
                        var mi = ty.GetMethod("Method", BindingFlags.Public | BindingFlags.Static);
                        results[2] = (bool) mi.Invoke (null, Array.Empty<object>());
                });
                threads[3] = new Thread(() => {
                        go.Wait();
                        var assm = Assembly.Load(an);
                        var ty = assm.GetType("RacingLib.Class4");
                        var mi = ty.GetMethod("Method", BindingFlags.Public | BindingFlags.Static);
                        results[3] = (bool) mi.Invoke (null, Array.Empty<object>());
                });
                foreach (var t in threads)
                {
                        t.Start();
                }
                go.Release(N);
                foreach (var t in threads)
                {
                        t.Join();
                }
#else
                var assm = Assembly.Load(an);
                var ty = assm.GetType("RacingLib.Class1");
                var mi = ty.GetMethod("Method", BindingFlags.Public | BindingFlags.Static);
                results[0] = (bool) mi.Invoke (null, Array.Empty<object>());
#endif
                int successes = 0;
                foreach (var r in results) {
                        if (r)
                                successes++;
                }
                return successes;
                
        }
}

