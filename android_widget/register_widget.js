// Registers the home screen widget receiver in the regenerated AndroidManifest.
// Run from the project root after `flutter create`.
const fs = require('fs');

const path = 'android/app/src/main/AndroidManifest.xml';
let manifest = fs.readFileSync(path, 'utf8');

if (!manifest.includes('UsageWidgetProvider')) {
  const receiver = [
    '        <receiver android:name=".UsageWidgetProvider" android:exported="true">',
    '            <intent-filter>',
    '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />',
    '            </intent-filter>',
    '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/usage_widget_info" />',
    '        </receiver>',
    '    </application>',
  ].join('\n');
  manifest = manifest.replace('</application>', receiver);
  fs.writeFileSync(path, manifest);
}

console.log(
  manifest.includes('UsageWidgetProvider')
    ? 'widget receiver registered'
    : 'FAILED to register widget receiver',
);
