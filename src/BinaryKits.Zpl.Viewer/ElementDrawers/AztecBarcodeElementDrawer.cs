using BinaryKits.Zpl.Label;
using BinaryKits.Zpl.Label.Elements;
using BinaryKits.Zpl.Viewer.Helpers;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using ZXing.Aztec;



namespace BinaryKits.Zpl.Viewer.ElementDrawers
{
    public class AztecBarcodeElementDrawer : BarcodeDrawerBase
    {
        ///<inheritdoc/>
        public override bool CanDraw(ZplElementBase element)
        {
            return element is ZplAztecBarcode;
        }

        ///<inheritdoc/>
        public override PointF Draw(ZplElementBase element, DrawerOptions options, PointF currentPosition, InternationalFont internationalFont)
        {
            // Assuming SKPoint is a defined struct/type that holds float X and Y.
            // We will keep the SKPoint type for the return value and arguments for structural compatibility.

            if (element is ZplAztecBarcode aztecBarcode)
            {
                float x = aztecBarcode.PositionX;
                float y = aztecBarcode.PositionY;

                if (aztecBarcode.UseDefaultPosition)
                {
                    x = currentPosition.X;
                    y = currentPosition.Y;
                }

                string content = aztecBarcode.Content;

                if (aztecBarcode.HexadecimalIndicator is char hexIndicator)
                {
                    // Assuming ReplaceHexEscapes is defined elsewhere and works
                    content = content.ReplaceHexEscapes(hexIndicator, internationalFont);
                }

                AztecWriter writer = new AztecWriter();
                AztecEncodingOptions encodingOptions = new AztecEncodingOptions();

                // ... (Error Control/Layer logic remains unchanged) ...
                if (aztecBarcode.ErrorControl >= 1 && aztecBarcode.ErrorControl <= 99)
                {
                    encodingOptions.ErrorCorrection = aztecBarcode.ErrorControl;
                }
                else if (aztecBarcode.ErrorControl >= 101 && aztecBarcode.ErrorControl <= 104)
                {
                    encodingOptions.Layers = 100 - aztecBarcode.ErrorControl;
                }
                else if (aztecBarcode.ErrorControl >= 201 && aztecBarcode.ErrorControl <= 232)
                {
                    encodingOptions.Layers = aztecBarcode.ErrorControl - 200;
                }
                else if (aztecBarcode.ErrorControl == 300)
                {
                    encodingOptions.PureBarcode = true;
                }
                else
                {
                    // default options
                }

                // ZXing.Net part is natively supported in .NET 4.0 and remains
                ZXing.Common.BitMatrix result = writer.encode(content, ZXing.BarcodeFormat.AZTEC, 0, 0, encodingOptions.Hints);

                // *** SKIA SHARP REPLACEMENT START ***
                byte[] png;
                int width, height;

                // Use the new System.Drawing helper method
                using (Bitmap resizedImage = BitMatrixToBitmap(result, aztecBarcode.MagnificationFactor))
                {
                    width = resizedImage.Width;
                    height = resizedImage.Height;

                    // Encode the Bitmap to a PNG byte array using System.Drawing
                    using (var ms = new MemoryStream())
                    {
                        resizedImage.Save(ms, ImageFormat.Png);
                        png = ms.ToArray();
                    }
                }
                // *** SKIA SHARP REPLACEMENT END ***

                // Assuming DrawBarcode and CalculateNextDefaultPosition are updated to accept the new image dimensions
                this.DrawBarcode(png, x, y, width, height, aztecBarcode.FieldOrigin != null, aztecBarcode.FieldOrientation);
                return this.CalculateNextDefaultPosition(x, y, width, height, aztecBarcode.FieldOrigin != null, aztecBarcode.FieldOrientation, currentPosition);
            }

            return currentPosition;
        }
    }
}
