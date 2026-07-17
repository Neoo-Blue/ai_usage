// Registers the widget receiver and its configure activity in the regenerated
// AndroidManifest. Run from the project root after `flutter create`.
const fs = require('fs');

const path = 'android/app/src/main/AndroidManifest.xml';
let manifest = fs.readFileSync(path, 'utf8');

if (!manifest.includes('UsageWidgetProvider')) {
  const block = [
    '        <receiver android:name=".UsageWidgetProvider" android:exported="true">',
    '            <intent-filter>',
    '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />',
    '            </intent-filter>',
    '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/usage_widget_info" />',
    '        </receiver>',
    '        <activity android:name=".WidgetConfigActivity" android:exported="true" android:theme="@style/LaunchTheme">',
    '            <intent-filter>',
    '                <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />',
    '            </intent-filter>',
    '        </activity>',
    '    </application>',
  ].join('\n');
  manifest = manifest.replace('</application>', block);
  fs.writeFileSync(path, manifest);
}

console.log(
  manifest.includes('WidgetConfigActivity')
    ? 'widget receiver and config activity registered'
    : 'FAILED to register widget',
);
