namespace android_button_app;

[Activity(Label = "@string/app_name", MainLauncher = true)]
public class MainActivity : Activity
{
    int count = 0;
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        // Set our view from the "main" layout resource
        SetContentView(Resource.Layout.activity_main);

        Button button = FindViewById<Button>(Resource.Id.button1);
        button.Click += delegate {
          button.Text = string.Format ("{0} clicks!", count++);
        };
    }
}