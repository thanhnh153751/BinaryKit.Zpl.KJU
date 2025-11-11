using BinaryKits.Zpl.Label.Helpers;
using BinaryKits.Zpl.Label.ImageConverters;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace BinaryKits.Zpl.Label.Elements
{
    /// <summary>
    /// Download Graphics<br/>
    /// The ~DG command downloads an ASCII Hex representation of a graphic image.
    /// If .GRF is not the specified file extension, .GRF is automatically appended.
    /// </summary>
    /// <remarks>
    /// Format:~DGd:o.x,t,w,data
    /// d = device to store image
    /// o = image name
    /// x = extension
    /// t = total number of bytes in graphic
    /// w = number of bytes per row
    /// data = ASCII hexadecimal string defining image
    /// </remarks>
    public class ZplDownloadGraphics : ZplDownload
    {
        public string ImageName { get; private set; }
        private string _extension { get; set; }
        public byte[] ImageData { get; private set; }

        private readonly IImageConverter _imageConverter;
        readonly ZplCompressionScheme _compressionScheme;

        /// <summary>
        /// Zpl Download Graphics
        /// </summary>
        /// <param name="storageDevice"></param>
        /// <param name="imageName"></param>
        /// <param name="imageData"></param>
        /// <param name="imageConverter"></param>
        /// <param name="compressionScheme"></param>
        public ZplDownloadGraphics(
            char storageDevice,
            string imageName,
            byte[] imageData,
            ZplCompressionScheme compressionScheme = ZplCompressionScheme.ACS,
            IImageConverter imageConverter = default)
            : base(storageDevice)
        {
            if (imageName.Length > 8)
            {
                new ArgumentException("maximum length of 8 characters exceeded", nameof(imageName));
            }

            _extension = "GRF"; //Fixed

            ImageName = imageName;
            ImageData = imageData;

            if (imageConverter == default)
            {
                imageConverter = new ImageSharpImageConverter();
            }
            _imageConverter = imageConverter;
            _compressionScheme = compressionScheme;
        }

        ///<inheritdoc/>
        public override IEnumerable<string> Render(ZplRenderOptions context)
        {
            byte[] objectData;

            // 1. Image Loading and Manipulation 
            using (var ms = new MemoryStream(ImageData))
            using (var originalImage = System.Drawing.Image.FromStream(ms))
            using (var image = new Bitmap(originalImage)) // Convert to Bitmap for manipulation
            {
                // Equivalent to SixLabors image.Mutate(x => x.Resize(...))
                if (context.ScaleFactor != 1)
                {
                    // Calculate new dimensions (replacing the commented-out SixLabors calculation with its logic)
                    // The original SixLabors code was using a hardcoded division by 2 for demonstration:
                    var scaleWidth = image.Width / 2;
                    var scaleHeight = image.Height / 2;

                    // System.Drawing equivalent of resizing: GetThumbnailImage is a simple resize method.
                    // NOTE: For higher-quality resizing, you may need to implement a custom Bitmap/Graphics routine.
                    using (var scaledImage = image.GetThumbnailImage(scaleWidth, scaleHeight, null, IntPtr.Zero))
                    {
                        // To replace the original image variable, we must save the scaled image
                        // and then reload it or save it directly to the output stream.
                        // We'll save the scaled image to memory stream for conversion.

                        using (var outputStream = new MemoryStream())
                        {
                            // 2. Image Saving (PNG format)
                            // The #if NET6_0_OR_GREATER block for PNG metadata is not needed
                            // as System.Drawing manages this differently/doesn't have the same issue.
                            scaledImage.Save(outputStream, ImageFormat.Png);
                            objectData = outputStream.ToArray();
                        }
                    }
                }
                else
                {
                    // If no scaling, just save the original image data as PNG
                    using (var outputStream = new MemoryStream())
                    {
                        image.Save(outputStream, ImageFormat.Png);
                        objectData = outputStream.ToArray();
                    }
                }
            } // The System.Drawing objects (Bitmap, Image, MemoryStream) are disposed here.

            // 3. Image Conversion (using the previously defined helper method)
            // The previous conversion method uses System.Drawing and is still valid here.
            var imageResult = _imageConverter.ConvertImage(objectData);
            string zplData = string.Empty;

            // 4. ZPL Compression and Output (No change needed here as it uses existing helpers)
            switch (_compressionScheme)
            {
                case ZplCompressionScheme.None:
                    zplData = imageResult.RawData.ToHexFromBytes();
                    break;
                case ZplCompressionScheme.ACS:
                    zplData = ZebraACSCompressionHelper.Compress(imageResult.RawData.ToHexFromBytes(), imageResult.BytesPerRow);
                    break;
                case ZplCompressionScheme.Z64:
                    //TODO: Reduce multiple conversions of byte array to string. 
                    zplData = ZebraZ64CompressionHelper.Compress(imageResult.RawData);
                    break;
                case ZplCompressionScheme.B64:
                    //TODO: Implement this compression scheme.
                    zplData = ZebraB64CompressionHelper.Compress(imageResult.RawData);
                    break;
                    //throw new NotSupportedException();
            }

            return new List<string>
            {
                $"~DG{StorageDevice}:{ImageName}.{_extension},{imageResult.BinaryByteCount},{imageResult.BytesPerRow},",
                zplData
            };
        }
    }
}
